{-# OPTIONS_GHC -funbox-strict-fields #-}
module StmHamt.Types where

import StmHamt.Prelude

{-|
STM-specialized Hash Array Mapped Trie,
extended with its size-tracking functionality,
allowing for a fast 'size' operation.
-}
data SizedHamt element = SizedHamt !(Hamt element) !(TVar Int)

{-|
STM-specialized Hash Array Mapped Trie.
-}
newtype Hamt element = Hamt (TVar (SparseSmallArray (Branch element)))

data Branch element = BranchesBranch !(Hamt element) | LeavesBranch !Hash !(SmallArray element)

{-|
An immutable space-efficient sparse array, 
which can store not more than 32 elements.
-}
data SparseSmallArray e = SparseSmallArray !Indices !(SmallArray e)

{-|
A compact set of indices.
-}
type Indices = Int

type Index = Int

type Position = Int

type Hash = Int
