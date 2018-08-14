module StmHamt.Hamt
(
  Hamt,
  new,
  newIO,
  null,
  focus,
  focusExplicitly,
  insert,
  insertExplicitly,
  lookup,
  lookupExplicitly,
  reset,
  unfoldM,
  listT,
)
where

import StmHamt.Prelude hiding (empty, insert, update, lookup, delete, null)
import StmHamt.Types
import qualified Focus as Focus
import qualified StmHamt.Focuses as Focuses
import qualified StmHamt.Constructors.Hash as HashConstructors
import qualified StmHamt.Accessors.Hash as HashAccessors
import qualified StmHamt.UnfoldMs as UnfoldMs
import qualified StmHamt.ListT as ListT
import qualified StmHamt.IntOps as IntOps
import qualified PrimitiveExtras.SmallArray as SmallArray
import qualified PrimitiveExtras.SparseSmallArray as SparseSmallArray


new :: STM (Hamt a)
new = Hamt <$> newTVar SparseSmallArray.empty

newIO :: IO (Hamt a)
newIO = Hamt <$> newTVarIO SparseSmallArray.empty

focus :: (Eq key, Hashable key) => Focus element STM result -> (element -> key) -> key -> Hamt element -> STM result
focus focus elementToKey key = focusExplicitly focus (hash key) ((==) key . elementToKey)

focusExplicitly :: Focus a STM b -> Int -> (a -> Bool) -> Hamt a -> STM b
focusExplicitly focus hash test hamt =
  {-# SCC "focus" #-} 
  let
    Focus conceal reveal = Focuses.onHamtElement hash test focus
    in fmap fst (reveal hamt)

{-|
Returns a flag, specifying, whether the size has been affected.
-}
insert :: (Eq key, Hashable key, Show element) => (element -> key) -> element -> Hamt element -> STM Bool
insert elementToKey element = let
  !key = elementToKey element
  in insertExplicitly (hash key) ((==) key . elementToKey) element

{-|
Returns a flag, specifying, whether the size has been affected.
-}
insertExplicitly :: Show a => Int -> (a -> Bool) -> a -> Hamt a -> STM Bool
insertExplicitly hash testKey element = {-# SCC "insertExplicitly" #-} iterate 0 where
  iterate depth (Hamt var) = let
    !branchIndex = IntOps.indexAtDepth depth hash
    in do
      branchArray <- readTVar var
      case SparseSmallArray.lookup branchIndex branchArray of
        Nothing -> do
          writeTVar var $! SparseSmallArray.insert branchIndex (LeavesBranch hash (pure element)) branchArray
          return True
        Just branch -> case branch of
          LeavesBranch leavesHash leavesArray ->
            if leavesHash == hash
              then case SmallArray.findWithIndex testKey leavesArray of
                Just (leavesIndex, leavesElement) -> let
                  !newLeavesArray = SmallArray.set leavesIndex element leavesArray
                  !newBranch = LeavesBranch hash newLeavesArray
                  !newBranchArray = SparseSmallArray.replace branchIndex newBranch branchArray
                  in do
                    writeTVar var newBranchArray
                    return False
                Nothing -> let
                  newLeavesArray = SmallArray.cons element leavesArray
                  in do
                    writeTVar var $! SparseSmallArray.replace branchIndex (LeavesBranch hash newLeavesArray) branchArray
                    return True
              else do
                hamt <- pair (IntOps.nextDepth depth) hash (LeavesBranch hash (pure element)) leavesHash (LeavesBranch leavesHash leavesArray)
                writeTVar var $! SparseSmallArray.replace branchIndex (BranchesBranch hamt) branchArray
                return True
          BranchesBranch hamt -> iterate (IntOps.nextDepth depth) hamt

pair :: Int -> Int -> Branch a -> Int -> Branch a -> STM (Hamt a)
pair depth hash1 branch1 hash2 branch2 =
  {-# SCC "pair" #-}
  let
    index1 = IntOps.indexAtDepth depth hash1
    index2 = IntOps.indexAtDepth depth hash2
    in if index1 == index2
        then do
          deeperHamt <- pair (IntOps.nextDepth depth) hash1 branch1 hash2 branch2
          var <- newTVar (SparseSmallArray.singleton index1 (BranchesBranch deeperHamt))
          return (Hamt var)
        else Hamt <$> newTVar (SparseSmallArray.pair index1 branch1 index2 branch2)

{-|
Returns a flag, specifying, whether the size has been affected.
-}
lookup :: (Eq key, Hashable key) => (element -> key) -> key -> Hamt element -> STM (Maybe element)
lookup elementToKey key = lookupExplicitly (hash key) ((==) key . elementToKey)

lookupExplicitly :: Int -> (a -> Bool) -> Hamt a -> STM (Maybe a)
lookupExplicitly hash test (Hamt var) =
  {-# SCC "lookupExplicitly" #-}
  let
    !index = HashAccessors.index hash
    in do
      branchArray <- readTVar var
      case SparseSmallArray.lookup index branchArray of
        Just branch -> case branch of
          LeavesBranch leavesHash leavesArray -> if leavesHash == hash
            then return (SmallArray.find test leavesArray)
            else return Nothing
          BranchesBranch hamt -> lookupExplicitly (HashConstructors.succLevel hash) test hamt
        Nothing -> return Nothing

reset :: Hamt a -> STM ()
reset (Hamt branchSsaVar) = writeTVar branchSsaVar SparseSmallArray.empty

unfoldM :: Hamt a -> UnfoldM STM a
unfoldM = UnfoldMs.hamtElements

listT :: Hamt a -> ListT STM a
listT = ListT.hamtElements

null :: Hamt a -> STM Bool
null (Hamt branchSsaVar) = do
  branchSsa <- readTVar branchSsaVar
  return (SparseSmallArray.null branchSsa)
