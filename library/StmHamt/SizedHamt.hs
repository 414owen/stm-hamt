-- |
-- HAMT API,
-- optimized for a fast 'size' operation.
-- That however comes at the cost of a small overhead in the other operations.
module StmHamt.SizedHamt
(
  SizedHamt,
  new,
  newIO,
  null,
  size,
  focus,
  insert,
  reset,
  unfoldM,
)
where

import StmHamt.Prelude hiding (insert, lookup, delete, fold, null)
import StmHamt.Types
import qualified Focus as Focus
import qualified StmHamt.Hamt as Hamt


{-# INLINE new #-}
new :: STM (SizedHamt element)
new = SizedHamt <$> Hamt.new <*> newTVar 0

{-# INLINE newIO #-}
newIO :: IO (SizedHamt element)
newIO = SizedHamt <$> Hamt.newIO <*> newTVarIO 0

-- |
-- /O(1)/.
{-# INLINE null #-}
null :: SizedHamt element -> STM Bool
null (SizedHamt _ sizeVar) = (== 0) <$> readTVar sizeVar

-- |
-- /O(1)/.
{-# INLINE size #-}
size :: SizedHamt element -> STM Int
size (SizedHamt _ sizeVar) = readTVar sizeVar

{-# INLINE reset #-}
reset :: SizedHamt element -> STM ()
reset (SizedHamt hamt sizeVar) =
  do
    Hamt.reset hamt
    writeTVar sizeVar 0

{-# INLINE focus #-}
focus :: (Eq element, Eq key, Hashable key) => Focus element STM result -> (element -> key) -> key -> SizedHamt element -> STM result
focus focus elementToKey key (SizedHamt hamt sizeVar) =
  do
    (result, sizeModifier) <- Hamt.focus newFocus (hash key) elementTest hamt
    forM_ sizeModifier (modifyTVar' sizeVar)
    return result
  where
    newFocus = Focus.testingSizeChange (Just pred) Nothing (Just succ) focus
    elementTest = (==) key . elementToKey

{-# INLINE insert #-}
insert :: (Eq element, Eq key, Hashable key) => (element -> key) -> element -> SizedHamt element -> STM ()
insert elementToKey element (SizedHamt nodes sizeVar) =
  do
    inserted <- Hamt.insert (hash key) elementTest element nodes
    when inserted (modifyTVar' sizeVar succ)
  where
    elementTest = (==) key . elementToKey
    key = elementToKey element

{-# INLINE unfoldM #-}
unfoldM :: SizedHamt a -> UnfoldM STM a
unfoldM (SizedHamt hamt _) = Hamt.unfoldM hamt
