"use client"

import type React from "react"
import { useState } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { X, Check, StickyNote } from "lucide-react"
import { Button } from "@/components/ui/button"

interface Task {
  id: number
  title: string
  source: string
  progress: number
  icon: React.ComponentType<{ className?: string }>
}

interface StickyIslandProps {
  isExpanded: boolean
  onToggle: () => void
  tasks: Task[]
}

const noteColors = [
  "from-yellow-200 to-yellow-300",
  "from-pink-200 to-pink-300",
  "from-blue-200 to-blue-300",
  "from-green-200 to-green-300",
]

export function StickyIsland({ isExpanded, onToggle, tasks }: StickyIslandProps) {
  const [completedTasks, setCompletedTasks] = useState<number[]>([])

  const handleComplete = (taskId: number) => {
    setCompletedTasks((prev) => [...prev, taskId])
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
            <div className="w-36 h-10 bg-gradient-to-r from-yellow-100 to-yellow-200 rounded-[2rem] shadow-lg border-2 border-yellow-400 flex items-center justify-center gap-1">
              <StickyNote className="h-4 w-4 text-yellow-700" />
              <span className="text-xs font-bold text-yellow-800">{tasks.length}</span>
            </div>
          </motion.button>
        ) : (
          <motion.div
            key="expanded"
            initial={{ height: 40, width: 144 }}
            animate={{ height: "auto", width: 360 }}
            className="bg-gradient-to-br from-amber-50 to-orange-50 rounded-3xl shadow-2xl border-2 border-amber-200 overflow-hidden"
          >
            <div className="p-4 bg-amber-100 border-b-2 border-amber-200 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <StickyNote className="h-4 w-4 text-amber-700" />
                <h3 className="text-sm font-bold text-amber-900">Sticky tasks</h3>
              </div>
              <Button variant="ghost" size="icon" className="h-8 w-8 text-amber-700" onClick={onToggle}>
                <X className="h-4 w-4" />
              </Button>
            </div>

            <div className="p-4 grid grid-cols-2 gap-3">
              {tasks.map((task, index) => {
                const Icon = task.icon
                const isCompleted = completedTasks.includes(task.id)
                const colorClass = noteColors[index % noteColors.length]

                return (
                  <motion.div
                    key={task.id}
                    initial={{ opacity: 0, rotate: -5, y: 20 }}
                    animate={{ opacity: 1, rotate: Math.random() * 4 - 2, y: 0 }}
                    transition={{ delay: 0.05 * index }}
                    className={`relative p-3 rounded-lg shadow-md ${isCompleted ? "opacity-50" : ""}`}
                    style={{
                      background: `linear-gradient(135deg, ${
                        colorClass.includes("yellow")
                          ? "#fef08a, #fde047"
                          : colorClass.includes("pink")
                            ? "#fbcfe8, #f9a8d4"
                            : colorClass.includes("blue")
                              ? "#bfdbfe, #93c5fd"
                              : "#bbf7d0, #86efac"
                      })`,
                    }}
                  >
                    {/* Tape effect */}
                    <div className="absolute -top-2 left-1/2 -translate-x-1/2 w-12 h-4 bg-white/50 backdrop-blur-sm rounded-sm" />

                    <div className="space-y-2">
                      <div className="flex items-center justify-between">
                        <Icon className="h-4 w-4 text-gray-700" />
                        {!isCompleted && (
                          <Button
                            size="sm"
                            variant="ghost"
                            className="h-6 w-6 p-0 hover:bg-white/50"
                            onClick={() => handleComplete(task.id)}
                          >
                            <Check className="h-3 w-3" />
                          </Button>
                        )}
                      </div>
                      <p className="text-xs font-medium text-gray-900 leading-tight text-balance">{task.title}</p>
                      <p className="text-[10px] text-gray-600">{task.source}</p>
                    </div>

                    {isCompleted && (
                      <motion.div
                        initial={{ scale: 0, rotate: -45 }}
                        animate={{ scale: 1, rotate: -15 }}
                        className="absolute inset-0 flex items-center justify-center"
                      >
                        <div className="px-4 py-1 bg-red-500 text-white text-xs font-bold rounded transform -rotate-12 shadow-lg">
                          DONE
                        </div>
                      </motion.div>
                    )}
                  </motion.div>
                )
              })}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
