"use client"

import type React from "react"
import { useState } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { X, Check, Clock, AlertCircle } from "lucide-react"
import { Button } from "@/components/ui/button"

interface Task {
  id: number
  title: string
  source: string
  progress: number
  icon: React.ComponentType<{ className?: string }>
}

interface TimelineIslandProps {
  isExpanded: boolean
  onToggle: () => void
  tasks: Task[]
}

export function TimelineIsland({ isExpanded, onToggle, tasks }: TimelineIslandProps) {
  const [completedTasks, setCompletedTasks] = useState<number[]>([])

  const handleComplete = (taskId: number) => {
    setCompletedTasks((prev) => [...prev, taskId])
  }

  const getUrgencyColor = (progress: number) => {
    if (progress < 30) return { bg: "bg-red-950/50", border: "border-red-600", text: "text-red-400", dot: "bg-red-500" }
    if (progress < 70)
      return { bg: "bg-orange-950/50", border: "border-orange-600", text: "text-orange-400", dot: "bg-orange-500" }
    return { bg: "bg-green-950/50", border: "border-green-600", text: "text-green-400", dot: "bg-green-500" }
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
            <div className="w-36 h-10 bg-gradient-to-r from-indigo-950 to-violet-950 rounded-[2rem] shadow-2xl border border-indigo-600 flex items-center justify-center gap-2">
              <Clock className="h-4 w-4 text-indigo-400" />
              <div className="flex gap-1">
                {tasks.slice(0, 3).map((task, i) => {
                  const colors = getUrgencyColor(task.progress)
                  return <div key={i} className={`w-1.5 h-1.5 rounded-full ${colors.dot}`} />
                })}
              </div>
            </div>
          </motion.button>
        ) : (
          <motion.div
            key="expanded"
            initial={{ height: 40, width: 144 }}
            animate={{ height: "auto", width: 360 }}
            className="bg-gradient-to-br from-indigo-950 via-violet-950 to-indigo-950 rounded-3xl shadow-2xl border border-indigo-700 overflow-hidden"
          >
            <div className="p-4 bg-indigo-900/30 border-b border-indigo-700 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Clock className="h-4 w-4 text-indigo-400" />
                <h3 className="text-sm font-semibold text-indigo-200">Timeline</h3>
              </div>
              <Button variant="ghost" size="icon" className="h-8 w-8 text-indigo-400" onClick={onToggle}>
                <X className="h-4 w-4" />
              </Button>
            </div>

            <div className="p-4 space-y-3">
              {tasks.map((task, index) => {
                const Icon = task.icon
                const isCompleted = completedTasks.includes(task.id)
                const colors = getUrgencyColor(task.progress)

                return (
                  <motion.div
                    key={task.id}
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: 0.05 * index }}
                    className="relative"
                  >
                    {/* Timeline line */}
                    {index < tasks.length - 1 && (
                      <div className="absolute left-[19px] top-10 w-0.5 h-6 bg-indigo-800/50" />
                    )}

                    <div
                      className={`p-3 rounded-xl border ${colors.bg} ${colors.border} ${
                        isCompleted ? "opacity-50" : ""
                      }`}
                    >
                      <div className="flex items-start gap-3">
                        <div
                          className={`w-10 h-10 rounded-full ${colors.bg} border-2 ${colors.border} flex items-center justify-center flex-shrink-0`}
                        >
                          {isCompleted ? (
                            <Check className={`h-5 w-5 ${colors.text}`} />
                          ) : (
                            <Icon className={`h-5 w-5 ${colors.text}`} />
                          )}
                        </div>

                        <div className="flex-1">
                          <div className="flex items-start justify-between gap-2">
                            <p className={`text-sm font-medium ${colors.text} text-balance`}>{task.title}</p>
                            {task.progress < 30 && !isCompleted && (
                              <AlertCircle className="h-4 w-4 text-red-400 flex-shrink-0" />
                            )}
                          </div>
                          <p className="text-xs text-indigo-400 mt-1">{task.source}</p>

                          {!isCompleted && (
                            <div className="mt-2 flex items-center gap-2">
                              <div className="flex-1 h-1.5 bg-indigo-900 rounded-full overflow-hidden">
                                <div className={`h-full ${colors.dot}`} style={{ width: `${task.progress}%` }} />
                              </div>
                              <span className="text-xs text-indigo-400 font-medium">{task.progress}%</span>
                            </div>
                          )}
                        </div>

                        {!isCompleted && (
                          <Button
                            size="sm"
                            className={`${colors.dot} hover:opacity-80 text-white`}
                            onClick={() => handleComplete(task.id)}
                          >
                            <Check className="h-4 w-4" />
                          </Button>
                        )}
                      </div>
                    </div>
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
