"use client"

import type React from "react"
import { useState } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { X, Check, Sprout, Leaf, Flower2 } from "lucide-react"
import { Button } from "@/components/ui/button"

interface Task {
  id: number
  title: string
  source: string
  progress: number
  icon: React.ComponentType<{ className?: string }>
}

interface GardenIslandProps {
  isExpanded: boolean
  onToggle: () => void
  tasks: Task[]
}

export function GardenIsland({ isExpanded, onToggle, tasks }: GardenIslandProps) {
  const [plantGrowth, setPlantGrowth] = useState<number[]>([])

  const handleComplete = (taskId: number) => {
    setPlantGrowth((prev) => [...prev, taskId])
  }

  const getPlantIcon = (taskId: number, index: number) => {
    if (plantGrowth.includes(taskId)) {
      return <Flower2 className="h-5 w-5 text-pink-400" />
    }
    if (index % 3 === 0) return <Sprout className="h-4 w-4 text-green-500" />
    if (index % 3 === 1) return <Leaf className="h-4 w-4 text-emerald-500" />
    return <Sprout className="h-4 w-4 text-lime-500" />
  }

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
          >
            <div className="w-36 h-10 bg-gradient-to-r from-emerald-900 to-green-900 rounded-[2rem] shadow-2xl border border-green-600 flex items-center justify-center gap-1">
              <Sprout className="h-4 w-4 text-green-400" />
              <Leaf className="h-3 w-3 text-emerald-400" />
              <Flower2 className="h-4 w-4 text-pink-400" />
            </div>
          </motion.button>
        ) : (
          <motion.div
            key="expanded"
            initial={{ height: 40, width: 144 }}
            animate={{ height: "auto", width: 360 }}
            className="bg-gradient-to-br from-green-950 via-emerald-950 to-green-950 rounded-3xl shadow-2xl border border-green-700 overflow-hidden"
          >
            <div className="p-4 bg-gradient-to-r from-green-900/30 to-emerald-900/30 border-b border-green-700 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Leaf className="h-4 w-4 text-green-400" />
                <h3 className="text-sm font-semibold text-green-200">Your garden</h3>
              </div>
              <Button variant="ghost" size="icon" className="h-8 w-8 text-green-400" onClick={onToggle}>
                <X className="h-4 w-4" />
              </Button>
            </div>

            <div className="p-3 space-y-2">
              {tasks.map((task, index) => {
                const isCompleted = plantGrowth.includes(task.id)

                return (
                  <motion.div
                    key={task.id}
                    initial={{ opacity: 0, scale: 0.8 }}
                    animate={{ opacity: 1, scale: 1 }}
                    transition={{ delay: 0.05 * index }}
                    className={`p-3 rounded-xl bg-green-900/20 border ${
                      isCompleted ? "border-pink-600/50" : "border-green-700/50"
                    }`}
                  >
                    <div className="flex items-start gap-3">
                      <motion.div
                        className="w-10 h-10 rounded-full bg-green-900/50 flex items-center justify-center"
                        animate={isCompleted ? { scale: [1, 1.2, 1] } : {}}
                        transition={{ duration: 0.5 }}
                      >
                        {getPlantIcon(task.id, index)}
                      </motion.div>

                      <div className="flex-1">
                        <p className="text-sm font-medium text-green-100 text-balance">{task.title}</p>
                        <p className="text-xs text-green-400 mt-1">{task.source}</p>
                        {isCompleted && (
                          <motion.p
                            initial={{ opacity: 0 }}
                            animate={{ opacity: 1 }}
                            className="text-xs text-pink-400 mt-1"
                          >
                            🌸 Bloomed!
                          </motion.p>
                        )}
                      </div>

                      {!isCompleted && (
                        <Button
                          size="sm"
                          className="bg-green-600 hover:bg-green-500 text-white"
                          onClick={() => handleComplete(task.id)}
                        >
                          <Check className="h-4 w-4" />
                        </Button>
                      )}
                    </div>
                  </motion.div>
                )
              })}
            </div>

            <div className="p-3 bg-green-900/20 border-t border-green-700/50 text-center">
              <p className="text-xs text-green-400">
                {plantGrowth.length} of {tasks.length} plants blooming
              </p>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
