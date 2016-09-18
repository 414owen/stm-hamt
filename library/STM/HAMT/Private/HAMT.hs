module STM.HAMT.Private.HAMT where

import STM.HAMT.Private.Prelude hiding (insert, lookup, delete, foldM)
import qualified STM.HAMT.Private.Nodes as Nodes
import qualified Focus.Impure


type HAMT e = Nodes.Nodes e

type Element e = (Nodes.Element e, Hashable (Nodes.ElementKey e))

{-# INLINE insert #-}
insert :: (Element e) => e -> HAMT e -> STM ()
insert e = Nodes.insert e (hash (Nodes.elementKey e)) (Nodes.elementKey e) 0

{-# INLINE focus #-}
focus :: (Element e) => Focus.Impure.Focus e STM r -> Nodes.ElementKey e -> HAMT e -> STM r
focus s k = Nodes.focus s (hash k) k 0

{-# INLINE foldM #-}
foldM :: (a -> e -> STM a) -> a -> HAMT e -> STM a
foldM step acc = Nodes.foldM step acc 0

{-# INLINE new #-}
new :: STM (HAMT e)
new = Nodes.new

{-# INLINE newIO #-}
newIO :: IO (HAMT e)
newIO = Nodes.newIO

{-# INLINE null #-}
null :: HAMT e -> STM Bool
null = Nodes.null

{-# INLINE stream #-}
stream :: HAMT e -> ListT STM e
stream = Nodes.stream 0

{-# INLINE deleteAll #-}
deleteAll :: HAMT e -> STM ()
deleteAll = Nodes.deleteAll
