module Physics.Sloth2D.Dynamics where

import Data.IntMap (IntMap)
import qualified Data.IntMap as M
import Data.List
import Data.Vector (Vector, (!))
import qualified Data.Vector as V

import Physics.Sloth2D.Body
import Physics.Sloth2D.Stepper
import Physics.Sloth2D.Vector2D

data Dynamics = Dynamics
    { manager :: Stepper
    , bodies :: IntMap Body
    , nextId :: Int
    }

dynamicWorld :: Float -> Float -> Dynamics
dynamicWorld tstep dtmax = Dynamics
    { manager = stepper tstep dtmax
    , bodies = M.empty
    , nextId = 0
    }

addBodies :: Dynamics -> [Body] -> (Dynamics, [Int])
addBodies world newBodies =
    (world { bodies = bodies', nextId = nextId' }, [firstId..nextId'-1])
  where
    firstId = nextId world
    (nextId',bodies') = foldl' add (firstId, bodies world) newBodies
    add (i,m) e = m' `seq` (i',m')
      where
        i' = i+1
        m' = M.insert i e m

advancedBy :: Dynamics -> Float -> Dynamics
world `advancedBy` dt = world
    { manager = m'
    , bodies = foldl' newBodies (bodies world) (replicate n sdt)
    }
  where
    (n,m') = advance dt (manager world)
    sdt = timeStep m'
    newBodies bodies dt = M.fromList $
                          zip (M.keys bodies) (V.toList (V.map (integrate dt) collbs))
      where
        bs = V.map shiftBody (V.fromList (M.elems bodies))
        num = V.length bs - 1
        collbs = V.accum addImpact bs [r | i1 <- [0..num], i2 <- [i1+1..num], r <- check i1 i2]
          where
            addImpact body (p,v,w) = body `nudgedBy` (v,w) `movedBy` (p*.0.3,0)
            check i1 i2 = case collisionResponse 1 (bs ! i1) (bs ! i2) of
                Nothing -> []
                Just (p1,v1,w1,p2,v2,w2) -> [(i1,(p1,v1,w1)),(i2,(p2,v2,w2))]