"use client"

import type React from "react"
import { useState, useEffect } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { X, Check, ChevronRight, Circle } from "lucide-react"
import { Button } from "@/components/ui/button"

interface Task {
  id: number
  title: string
  source: string
  progress: number
  icon: React.ComponentType<{ className?: string }>
}

interface ZenIslandProps {
  isExpanded: boolean
  onToggle: () => void
  tasks: Task[]
}

export function ZenIsland({ isExpanded, onToggle, tasks }: ZenIslandProps) {
  const [currentTaskIndex, setCurrentTaskIndex] = useState(0)
  const [breathScale, setBreathScale] = useState(1)

  useEffect(() => {
    const interval = setInterval(() => {
      setBreathScale((prev) => (prev === 1 ? 1.15 : 1))
    }, 3000)
    return () => clearInterval(interval)
  }, [])

  const currentTask = tasks[currentTaskIndex]

  return (
    <div className="fixed top-4 left-1/2 -translate-x-1/2 z-50">
      <AnimatePresence mode="wait">
        {!isExpanded ? (
          <motion.button
            key="idle"
            initial={{ scale: 0.8, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ scale: 0.8, opacity: 0 }}
            onClick={onToggle}
            className="relative"
          >
            <motion.div
              className="w-36 h-10 bg-gradient-to-r from-slate-900 to-slate-800 rounded-[2rem] shadow-2xl border border-slate-700 flex items-center justify-center"
              animate={{ scale: breathScale }}
              transition={{ duration: 3, ease: "easeInOut" }}
            >
              <Circle className="h-3 w-3 text-slate-300" strokeWidth={1} />
            </motion.div>
          </motion.button>
        ) : (
          <motion.div
            key="expanded"
            initial={{ height: 40, width: 144 }}
            animate={{ height: "auto", width: 320 }}
            className="bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 rounded-3xl shadow-2xl border border-slate-700 overflow-hidden"
          >
            <div className="p-6 space-y-6">
              <div className="flex items-center justify-between">
                <span className="text-xs text-slate-400 uppercase tracking-wider">Focus</span>
                <Button variant="ghost" size="icon" className="h-6 w-6 text-slate-400" onClick={onToggle}>
                  <X className="h-3 w-3" />
                </Button>
              </div>

              <motion.div
                key={currentTaskIndex}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                className="text-center space-y-4"
              >
                <motion.div
                  className="w-16 h-16 mx-auto rounded-full bg-slate-800 border border-slate-600 flex items-center justify-center"
                  animate={{ scale: breathScale }}
                  transition={{ duration: 3, ease: "easeInOut" }}
                >
                  <Circle className="h-8 w-8 text-slate-300" strokeWidth={1} />
                </motion.div>

                <h3 className="text-lg font-medium text-white text-balance">{currentTask.title}</h3>
                <p className="text-xs text-slate-500">{currentTask.source}</p>

                <div className="flex items-center justify-center gap-3 pt-2">
                  <Button
                    size="sm"
                    className="bg-slate-700 hover:bg-slate-600 text-white"
                    onClick={() => setCurrentTaskIndex((prev) => (prev + 1) % tasks.length)}
                  >
                    <Check className="h-4 w-4 mr-2" />
                    Complete
                  </Button>
                  {currentTaskIndex < tasks.length - 1 && (
                    <Button
                      size="sm"
                      variant="ghost"
                      className="text-slate-400"
                      onClick={() => setCurrentTaskIndex((prev) => prev + 1)}
                    >
                      <ChevronRight className="h-4 w-4" />
                    </Button>
                  )}
                </div>
              </motion.div>

              <div className="text-center text-xs text-slate-500">
                {currentTaskIndex + 1} of {tasks.length}
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
