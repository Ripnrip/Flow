"use client"

import type React from "react"
import { useState, useEffect } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { 
  Play, 
  Pause, 
  SkipForward, 
  SkipBack, 
  Calendar, 
  Music, 
  Battery, 
  Volume2, 
  Sun,
  MoreHorizontal,
  X,
  Maximize2
} from "lucide-react"
import { Button } from "@/components/ui/button"
import { cn } from "@/lib/utils"

interface AlcoveIslandProps {
  isExpanded: boolean
  onToggle: () => void
}

type IslandMode = "idle" | "music" | "calendar" | "duo" | "hud"

export function AlcoveIsland({ isExpanded, onToggle }: AlcoveIslandProps) {
  const [mode, setMode] = useState<IslandMode>("music")
  const [isPlaying, setIsPlaying] = useState(false)
  const [batteryLevel, setBatteryLevel] = useState(85)
  const [volume, setVolume] = useState(65)
  const [brightness, setBrightness] = useState(80)

  // Simulate waveform animation
  const [waveform, setWaveform] = useState<number[]>([])
  useEffect(() => {
    if (isPlaying) {
      const interval = setInterval(() => {
        setWaveform(Array.from({ length: 12 }, () => Math.random() * 100))
      }, 150)
      return () => clearInterval(interval)
    } else {
      setWaveform(Array.from({ length: 12 }, () => 20))
    }
  }, [isPlaying])

  const renderCompactMusic = () => (
    <div className="flex items-center gap-3 px-3 h-full w-full">
      <div className="w-6 h-6 rounded-md bg-gradient-to-br from-pink-500 to-purple-600 flex items-center justify-center overflow-hidden">
        <Music className="h-3 w-3 text-white" />
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-[11px] font-medium text-white truncate">Starboy</p>
      </div>
      <div className="flex items-end gap-[2px] h-3">
        {waveform.map((h, i) => (
          <motion.div
            key={i}
            className="w-[2px] bg-pink-500 rounded-full"
            animate={{ height: `${h}%` }}
            transition={{ type: "spring", damping: 15, stiffness: 200 }}
          />
        ))}
      </div>
    </div>
  )

  const renderExpandedMusic = () => (
    <div className="p-4 space-y-4">
      <div className="flex items-center gap-4">
        <motion.div 
          layoutId="album-art"
          className="w-16 h-16 rounded-xl bg-gradient-to-br from-pink-500 to-purple-600 shadow-lg flex items-center justify-center"
        >
          <Music className="h-8 w-8 text-white" />
        </motion.div>
        <div className="flex-1 min-w-0">
          <h3 className="text-base font-bold text-white truncate">Starboy</h3>
          <p className="text-sm text-zinc-400 truncate">The Weeknd • Starboy</p>
          <div className="flex gap-2 mt-1">
            <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-zinc-800 text-zinc-400 border border-zinc-700">LOSSLESS</span>
            <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-zinc-800 text-zinc-400 border border-zinc-700">DOLBY ATMOS</span>
          </div>
        </div>
      </div>

      <div className="space-y-2">
        <div className="flex items-center justify-between text-[10px] text-zinc-500">
          <span>1:24</span>
          <div className="flex-1 mx-3 h-1 bg-zinc-800 rounded-full overflow-hidden">
            <motion.div 
              className="h-full bg-white" 
              initial={{ width: "0%" }}
              animate={{ width: "40%" }}
            />
          </div>
          <span>3:50</span>
        </div>
        
        <div className="flex items-center justify-center gap-6 py-2">
          <Button variant="ghost" size="icon" className="text-white hover:bg-zinc-800">
            <SkipBack className="h-5 w-5 fill-current" />
          </Button>
          <Button 
            variant="ghost" 
            size="icon" 
            className="h-12 w-12 rounded-full bg-white text-black hover:bg-zinc-200"
            onClick={() => setIsPlaying(!isPlaying)}
          >
            {isPlaying ? <Pause className="h-6 w-6 fill-current" /> : <Play className="h-6 w-6 fill-current ml-1" />}
          </Button>
          <Button variant="ghost" size="icon" className="text-white hover:bg-zinc-800">
            <SkipForward className="h-5 w-5 fill-current" />
          </Button>
        </div>
      </div>
    </div>
  )

  const renderCompactCalendar = () => (
    <div className="flex items-center gap-3 px-3 h-full w-full">
      <div className="w-6 h-6 rounded-md bg-red-500 flex items-center justify-center">
        <Calendar className="h-3 w-3 text-white" />
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-[11px] font-medium text-white truncate">Design Sync</p>
      </div>
      <span className="text-[10px] font-bold text-red-400">14m</span>
    </div>
  )

  const renderExpandedCalendar = () => (
    <div className="p-4 space-y-4">
      <div className="flex items-start justify-between">
        <div className="space-y-1">
          <h3 className="text-lg font-bold text-white">Design Sync</h3>
          <p className="text-sm text-zinc-400 flex items-center gap-2">
            <Calendar className="h-3 w-3" />
            10:30 AM - 11:30 AM
          </p>
          <p className="text-sm text-zinc-400">Meeting Room 4 or Zoom</p>
        </div>
        <div className="w-12 h-12 rounded-2xl bg-zinc-900 border border-zinc-800 flex flex-col items-center justify-center">
          <span className="text-[10px] font-bold text-red-500 uppercase">Apr</span>
          <span className="text-lg font-bold text-white">07</span>
        </div>
      </div>
      
      <div className="flex gap-2">
        <Button className="flex-1 bg-white text-black hover:bg-zinc-200 font-bold">Join Meeting</Button>
        <Button variant="outline" className="flex-1 border-zinc-700 text-white hover:bg-zinc-800">Dismiss</Button>
      </div>
    </div>
  )

  const renderDuoMode = () => (
    <div className="flex h-12 divide-x divide-zinc-800">
      <div className="flex-1 flex items-center justify-center gap-2 px-3 overflow-hidden">
        <div className="w-5 h-5 rounded bg-gradient-to-br from-pink-500 to-purple-600 flex-shrink-0 flex items-center justify-center">
          <Music className="h-2.5 w-2.5 text-white" />
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-[10px] font-medium text-white truncate">Starboy</p>
        </div>
      </div>
      <div className="flex-1 flex items-center justify-center gap-2 px-3 overflow-hidden">
        <div className="w-5 h-5 rounded bg-red-500 flex-shrink-0 flex items-center justify-center">
          <Calendar className="h-2.5 w-2.5 text-white" />
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-[10px] font-medium text-white truncate">Design Sync</p>
        </div>
      </div>
    </div>
  )

  const renderHUD = () => (
    <div className="p-4 space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <div className="space-y-2">
          <div className="flex items-center justify-between text-xs text-zinc-400">
            <span className="flex items-center gap-1"><Volume2 className="h-3 w-3" /> Volume</span>
            <span>{volume}%</span>
          </div>
          <div className="h-2 bg-zinc-800 rounded-full overflow-hidden">
            <motion.div className="h-full bg-white" animate={{ width: `${volume}%` }} />
          </div>
        </div>
        <div className="space-y-2">
          <div className="flex items-center justify-between text-xs text-zinc-400">
            <span className="flex items-center gap-1"><Sun className="h-3 w-3" /> Brightness</span>
            <span>{brightness}%</span>
          </div>
          <div className="h-2 bg-zinc-800 rounded-full overflow-hidden">
            <motion.div className="h-full bg-white" animate={{ width: `${brightness}%` }} />
          </div>
        </div>
      </div>
      <div className="flex items-center justify-between p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
        <div className="flex items-center gap-3">
          <Battery className={cn("h-5 w-5", batteryLevel < 20 ? "text-red-500" : "text-green-500")} />
          <div className="space-y-0.5">
            <p className="text-sm font-bold text-white">MacBook Pro</p>
            <p className="text-[10px] text-zinc-500">Power Source: Battery</p>
          </div>
        </div>
        <span className="text-lg font-bold text-white">{batteryLevel}%</span>
      </div>
    </div>
  )

  return (
    <div className="fixed top-4 left-1/2 -translate-x-1/2 z-50">
      <AnimatePresence mode="wait">
        {!isExpanded ? (
          <motion.button
            key="compact"
            initial={{ scale: 0.8, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ scale: 0.8, opacity: 0 }}
            onClick={onToggle}
            className="relative group"
          >
            <div className={cn(
              "h-10 bg-black rounded-[2rem] shadow-2xl border border-zinc-800 flex items-center justify-center overflow-hidden transition-all duration-500",
              mode === "duo" ? "w-64" : "w-48"
            )}>
              {mode === "music" && renderCompactMusic()}
              {mode === "calendar" && renderCompactCalendar()}
              {mode === "duo" && renderDuoMode()}
              {mode === "idle" && (
                <div className="flex items-center gap-2">
                  <motion.div
                    className="w-2 h-2 rounded-full bg-blue-400"
                    animate={{ scale: [1, 1.5, 1], opacity: [1, 0.5, 1] }}
                    transition={{ duration: 2, repeat: Infinity }}
                  />
                  <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Flow</span>
                </div>
              )}
            </div>
          </motion.button>
        ) : (
          <motion.div
            key="expanded"
            initial={{ height: 40, width: mode === "duo" ? 256 : 192, borderRadius: 32 }}
            animate={{ height: "auto", width: 380, borderRadius: 28 }}
            exit={{ height: 40, width: mode === "duo" ? 256 : 192, borderRadius: 32 }}
            transition={{ type: "spring", damping: 25, stiffness: 300 }}
            className="bg-black shadow-2xl border border-zinc-800 overflow-hidden"
          >
            {/* Mode Switcher */}
            <div className="px-4 py-2 border-b border-zinc-800/50 flex items-center justify-between bg-zinc-900/20">
              <div className="flex gap-1">
                {(["music", "calendar", "duo", "hud"] as IslandMode[]).map((m) => (
                  <button
                    key={m}
                    onClick={() => setMode(m)}
                    className={cn(
                      "px-2 py-1 rounded-md text-[10px] font-bold uppercase transition-colors",
                      mode === m ? "bg-white text-black" : "text-zinc-500 hover:text-white"
                    )}
                  >
                    {m}
                  </button>
                ))}
              </div>
              <Button
                variant="ghost"
                size="icon"
                className="h-6 w-6 text-zinc-500 hover:text-white"
                onClick={onToggle}
              >
                <X className="h-3 w-3" />
              </Button>
            </div>

            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.1 }}
            >
              {mode === "music" && renderExpandedMusic()}
              {mode === "calendar" && renderExpandedCalendar()}
              {mode === "duo" && (
                <div className="divide-y divide-zinc-800">
                  {renderExpandedMusic()}
                  {renderExpandedCalendar()}
                </div>
              )}
              {mode === "hud" && renderHUD()}
            </motion.div>

            {/* Footer / Gestures Hint */}
            <div className="px-4 py-2 bg-zinc-900/40 border-t border-zinc-800/50 flex items-center justify-between">
              <span className="text-[9px] font-bold text-zinc-600 uppercase tracking-tighter">Swipe to switch modes</span>
              <div className="flex gap-1">
                <div className="w-1 h-1 rounded-full bg-zinc-700" />
                <div className="w-1 h-1 rounded-full bg-zinc-700" />
                <div className="w-1 h-1 rounded-full bg-zinc-400" />
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
