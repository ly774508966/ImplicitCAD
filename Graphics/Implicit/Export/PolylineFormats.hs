{-# LANGUAGE OverloadedStrings #-}

-- Implicit CAD. Copyright (C) 2011, Christopher Olah (chris@colah.ca)
-- Released under the GNU GPL, see LICENSE

module Graphics.Implicit.Export.PolylineFormats where

import Graphics.Implicit.Definitions

import Text.Printf (printf)

import Data.Text.Lazy (Text,unwords,pack)

import Text.Blaze.Svg.Renderer.Text (renderSvg)
import Text.Blaze.Svg
import Text.Blaze.Svg11 ((!),docTypeSvg,g,polyline,toValue)
import qualified Text.Blaze.Svg11.Attributes as A

import Data.List (foldl')

import Data.Monoid (mempty)

import Prelude hiding (unwords)

svg :: [Polyline] -> Text
svg = renderSvg . svg11 . svg'
    where       
      svg11 content = docTypeSvg ! A.version "1.1" $ content
      -- The reason this isn't totally straightforwards is that svg has different coordinate system
      -- and we need to compute the requisite translation.
      svg' [] = mempty 
      -- When we have a known point, we can compute said transformation:
      svg' polylines@((start:_):_) = let mm = foldl' (foldl' minmax) start polylines
                                     in thinBlueGroup $ mapM_ (poly mm) polylines
      -- Otherwise, if we don't have a point to start out with, skip this polyline:
      svg' ([]:rest) = svg' rest

      minmax (xa,ya) (xb,yb) = (min xa xb, max ya yb)
      
      poly (minx,maxy) line = polyline ! A.points pointList 
          where pointList = toValue $ unwords [pack $ show (x-minx) ++ "," ++ show (maxy - y) | (x,y) <- line]
      -- Instead of setting styles on every polyline, we wrap the lines in a group element and set the styles on it:
      thinBlueGroup = g ! A.stroke "rgb(0,0,255)" ! A.strokeWidth "1" ! A.fill "none" -- $ obj

hacklabLaserGCode :: [Polyline] -> Text
hacklabLaserGCode polylines = pack text
        where
                gcodeHeader = 
			"(generated by ImplicitCAD, based of hacklab wiki example)\n"
			++"M63 P0 (laser off)\n"
			++"G0 Z0.002 (laser off)\n"
			++"G21 (units=mm)\n"
			++"F400 (set feedrate)\n"
			++"M3 S1 (enable laser)\n"
			++"\n"
		gcodeFooter = 
			"M5 (disable laser)\n"
			++"G00 X0.0 Y0.0 (move to 0)\n"
			++"M2 (end)"
		showF n = printf "%.4f" n
		gcodeXY :: ℝ2 -> String
		gcodeXY (x,y) = "X"++ showF x ++" Y"++ showF y 
		interpretPolyline (start:others) = 
			"G00 "++ gcodeXY start ++ "\n"
			++ "M62 P0 (laser on)\n"
			++ concat (map (\p -> "G01 " ++ (gcodeXY p) ++ "\n") others)
			++ "M63 P0 (laser off)\n\n"
		text = gcodeHeader
			++ (concat $ map interpretPolyline polylines)
			++ gcodeFooter

