"use client"

import type React from "react"
import { useState } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { X, Check, Sparkles, Zap } from "lucide-react"
import { Button } from "@/components/ui/button"

interface Task {
  id: number
  title: string
  source: string
  progress: number
  icon: React.ComponentType<{ className?: string }>
}

interface HolographicIslandProps {
  isExpanded: boolean
  onToggle: () => void
  tasks: Task[]
}

export function HolographicIsland({ isExpanded, onToggle, tasks }: HolographicIslandProps) {
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
            className="relative"
          >
            <motion.div
              className="w-36 h-10 bg-black rounded-[2rem] shadow-2xl border border-cyan-500/50 flex items-center justify-center relative overflow-hidden"
              animate={{
                boxShadow: [
                  "0 0 20px rgba(6, 182, 212, 0.3)",
                  "0 0 40px rgba(168, 85, 247, 0.4)",
                  "0 0 20px rgba(6, 182, 212, 0.3)",
                ],
              }}
              transition={{ duration: 2, repeat: Number.POSITIVE_INFINITY }}
            >
              <div className="absolute inset-0 bg-gradient-to-r from-cyan-500/20 via-purple-500/20 to-cyan-500/20 animate-pulse" />
              <Sparkles className="h-4 w-4 text-cyan-400" />
            </motion.div>

            {/* Particle effects */}
            {[...Array(3)].map((_, i) => (
              <motion.div
                key={i}
                className="absolute w-1 h-1 bg-cyan-400 rounded-full"
                initial={{ x: 0, y: 0, opacity: 0 }}
                animate={{
                  x: [0, Math.random() * 40 - 20],
                  y: [0, -30],
                  opacity: [0, 1, 0],
                }}
                transition={{
                  duration: 2,
                  repeat: Number.POSITIVE_INFINITY,
                  delay: i * 0.7,
                }}
              />
            ))}
          </motion.button>
        ) : (
          <motion.div
            key="expanded"
            initial={{ height: 40, width: 144 }}
            animate={{ height: "auto", width: 360 }}
            className="bg-black rounded-3xl shadow-2xl border border-cyan-500/50 overflow-hidden relative"
            style={{
              boxShadow: "0 0 60px rgba(6, 182, 212, 0.4), 0 0 100px rgba(168, 85, 247, 0.2)",
            }}
          >
            {/* Animated background grid */}
            <div className="absolute inset-0 opacity-20">
              <div
                className="w-full h-full"
                style={{
                  backgroundImage:
                    "linear-gradient(cyan 1px, transparent 1px), linear-gradient(90deg, cyan 1px, transparent 1px)",
                  backgroundSize: "20px 20px",
                }}
              />
            </div>

            <div className="relative z-10 p-4 bg-gradient-to-r from-cyan-950/50 to-purple-950/50 border-b border-cyan-500/30 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Zap className="h-4 w-4 text-cyan-400" />
                <h3 className="text-sm font-semibold text-cyan-200">Neural tasks</h3>
              </div>
              <Button variant="ghost" size="icon" className="h-8 w-8 text-cyan-400" onClick={onToggle}>
                <X className="h-4 w-4" />
              </Button>
            </div>

            <div className="relative z-10 p-3 space-y-2">
              {tasks.map((task, index) => {
                const Icon = task.icon
                const isCompleted = completedTasks.includes(task.id)

                return (
                  <motion.div
                    key={task.id}
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: 0.05 * index }}
                    className={`p-3 rounded-xl bg-cyan-950/30 border backdrop-blur-sm ${
                      isCompleted ? "border-purple-500/50 opacity-60" : "border-cyan-500/30"
                    }`}
                    style={
                      !isCompleted
                        ? {
                            boxShadow: "0 0 20px rgba(6, 182, 212, 0.1)",
                          }
                        : {}
                    }
                  >
                    <div className="flex items-start gap-3">
                      <div className="w-10 h-10 rounded-lg bg-cyan-900/50 border border-cyan-500/50 flex items-center justify-center">
                        <Icon className="h-5 w-5 text-cyan-300" />
                      </div>

                      <div className="flex-1">
                        <p className="text-sm font-medium text-cyan-100 text-balance">{task.title}</p>
                        <p className="text-xs text-cyan-400 mt-1">{task.source}</p>
                      </div>

                      {!isCompleted && (
                        <Button
                          size="sm"
                          className="bg-cyan-600 hover:bg-cyan-500 text-black font-semibold"
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
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
