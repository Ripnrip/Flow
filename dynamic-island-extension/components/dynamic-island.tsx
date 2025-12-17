"use client"

import type React from "react"

import { useState } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { X, Check, Clock, MoreHorizontal } from "lucide-react"
import { Button } from "@/components/ui/button"
import { cn } from "@/lib/utils"

interface Task {
  id: number
  title: string
  source: string
  progress: number
  icon: React.ComponentType<{ className?: string }>
}

interface DynamicIslandProps {
  isExpanded: boolean
  onToggle: () => void
  tasks: Task[]
}

export function DynamicIsland({ isExpanded, onToggle, tasks }: DynamicIslandProps) {
  const [completedTasks, setCompletedTasks] = useState<number[]>([])

  const handleComplete = (taskId: number) => {
    setCompletedTasks((prev) => [...prev, taskId])
  }

  const handleSnooze = (taskId: number) => {
    console.log("[v0] Snoozing task:", taskId)
  }

  return (
    <div className="fixed top-4 left-1/2 -translate-x-1/2 z-50">
      <AnimatePresence mode="wait">
        {!isExpanded ? (
          // Idle State
          <motion.button
            key="idle"
            initial={{ scale: 0.8, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ scale: 0.8, opacity: 0 }}
            onClick={onToggle}
            className="relative group"
          >
            {/* Main island shape */}
            <div className="w-36 h-10 bg-black rounded-[2rem] shadow-2xl border border-zinc-800 flex items-center justify-center overflow-hidden">
              {/* Ambient glow */}
              <div className="absolute inset-0 bg-gradient-to-r from-blue-500/20 via-purple-500/20 to-pink-500/20 opacity-0 group-hover:opacity-100 transition-opacity duration-500" />

              {/* Pulse indicator */}
              <motion.div
                className="w-3 h-3 rounded-full bg-blue-400"
                animate={{
                  scale: [1, 1.2, 1],
                  opacity: [1, 0.5, 1],
                }}
                transition={{
                  duration: 2,
                  repeat: Number.POSITIVE_INFINITY,
                  ease: "easeInOut",
                }}
              />

              {/* Task count badge */}
              <div className="absolute right-3 w-5 h-5 rounded-full bg-zinc-800 flex items-center justify-center text-[10px] font-semibold text-zinc-400">
                {tasks.length}
              </div>
            </div>

            {/* Floating wave effect */}
            <motion.div
              className="absolute inset-0 rounded-[2rem] border border-blue-400/30"
              animate={{
                scale: [1, 1.1, 1],
                opacity: [0.5, 0, 0.5],
              }}
              transition={{
                duration: 3,
                repeat: Number.POSITIVE_INFINITY,
                ease: "easeOut",
              }}
            />
          </motion.button>
        ) : (
          // Expanded State
          <motion.div
            key="expanded"
            initial={{ height: 40, width: 144, borderRadius: 32 }}
            animate={{ height: "auto", width: 360, borderRadius: 24 }}
            exit={{ height: 40, width: 144, borderRadius: 32 }}
            transition={{ type: "spring", damping: 25, stiffness: 300 }}
            className="bg-black shadow-2xl border border-zinc-800 overflow-hidden"
          >
            {/* Header */}
            <div className="p-4 border-b border-zinc-800/50 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-2 h-2 rounded-full bg-blue-400 animate-pulse" />
                <h3 className="text-sm font-semibold text-white">Today's tasks</h3>
              </div>
              <Button
                variant="ghost"
                size="icon"
                className="h-8 w-8 text-zinc-400 hover:text-white hover:bg-zinc-800"
                onClick={onToggle}
              >
                <X className="h-4 w-4" />
              </Button>
            </div>

            {/* Tasks List */}
            <motion.div
              className="p-3 space-y-2 max-h-80 overflow-y-auto"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.1 }}
            >
              {tasks.map((task, index) => {
                const Icon = task.icon
                const isCompleted = completedTasks.includes(task.id)

                return (
                  <motion.div
                    key={task.id}
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.05 * index }}
                    className={cn(
                      "p-3 rounded-xl bg-zinc-900/50 border border-zinc-800/50 backdrop-blur-sm hover:bg-zinc-900 transition-colors",
                      isCompleted && "opacity-50",
                    )}
                  >
                    <div className="flex items-start gap-3">
                      {/* Icon */}
                      <div className="w-8 h-8 rounded-lg bg-zinc-800/50 flex items-center justify-center flex-shrink-0">
                        <Icon className="h-4 w-4 text-zinc-400" />
                      </div>

                      {/* Content */}
                      <div className="flex-1 min-w-0">
                        <p
                          className={cn(
                            "text-sm font-medium text-white mb-1 text-balance",
                            isCompleted && "line-through text-zinc-500",
                          )}
                        >
                          {task.title}
                        </p>
                        <div className="flex items-center gap-2 mb-2">
                          <span className="text-xs text-zinc-500">{task.source}</span>
                          {task.progress > 0 && (
                            <>
                              <span className="text-zinc-700">•</span>
                              <span className="text-xs text-zinc-500">{task.progress}% complete</span>
                            </>
                          )}
                        </div>

                        {/* Progress bar */}
                        {task.progress > 0 && !isCompleted && (
                          <div className="w-full h-1 bg-zinc-800 rounded-full overflow-hidden">
                            <motion.div
                              className="h-full bg-gradient-to-r from-blue-400 to-purple-400"
                              initial={{ width: 0 }}
                              animate={{ width: `${task.progress}%` }}
                              transition={{ delay: 0.2 + 0.05 * index, duration: 0.5 }}
                            />
                          </div>
                        )}
                      </div>

                      {/* Actions */}
                      {!isCompleted && (
                        <div className="flex items-center gap-1 flex-shrink-0">
                          <Button
                            variant="ghost"
                            size="icon"
                            className="h-8 w-8 text-zinc-400 hover:text-green-400 hover:bg-green-400/10"
                            onClick={() => handleComplete(task.id)}
                          >
                            <Check className="h-4 w-4" />
                          </Button>
                          <Button
                            variant="ghost"
                            size="icon"
                            className="h-8 w-8 text-zinc-400 hover:text-blue-400 hover:bg-blue-400/10"
                            onClick={() => handleSnooze(task.id)}
                          >
                            <Clock className="h-4 w-4" />
                          </Button>
                        </div>
                      )}
                    </div>
                  </motion.div>
                )
              })}
            </motion.div>

            {/* Footer */}
            <motion.div
              className="p-3 border-t border-zinc-800/50"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.2 }}
            >
              <Button
                variant="ghost"
                size="sm"
                className="w-full text-zinc-400 hover:text-white hover:bg-zinc-800 text-xs"
              >
                <MoreHorizontal className="h-3 w-3 mr-2" />
                View all tasks
              </Button>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
