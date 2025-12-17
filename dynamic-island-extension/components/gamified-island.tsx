"use client"

import type React from "react"
import { useState } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { X, Check, Zap, Award, TrendingUp } from "lucide-react"
import { Button } from "@/components/ui/button"

interface Task {
  id: number
  title: string
  source: string
  progress: number
  icon: React.ComponentType<{ className?: string }>
}

interface GamifiedIslandProps {
  isExpanded: boolean
  onToggle: () => void
  tasks: Task[]
}

export function GamifiedIsland({ isExpanded, onToggle, tasks }: GamifiedIslandProps) {
  const [xp, setXp] = useState(850)
  const [level, setLevel] = useState(7)
  const [completedCount, setCompletedCount] = useState<number[]>([])

  const handleComplete = (taskId: number, xpReward: number) => {
    setCompletedCount((prev) => [...prev, taskId])
    setXp((prev) => prev + xpReward)
    if (xp + xpReward >= 1000) {
      setLevel((prev) => prev + 1)
      setXp(0)
    }
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
            <div className="w-36 h-10 bg-gradient-to-r from-amber-900 to-orange-900 rounded-[2rem] shadow-2xl border-2 border-amber-600 flex items-center justify-center gap-2">
              <Zap className="h-4 w-4 text-amber-400 fill-amber-400" />
              <span className="text-xs font-bold text-amber-200">Lv.{level}</span>
            </div>
          </motion.button>
        ) : (
          <motion.div
            key="expanded"
            initial={{ height: 40, width: 144 }}
            animate={{ height: "auto", width: 360 }}
            className="bg-gradient-to-br from-amber-950 via-orange-950 to-amber-950 rounded-3xl shadow-2xl border-2 border-amber-700 overflow-hidden"
          >
            <div className="p-4 bg-gradient-to-r from-amber-900/50 to-orange-900/50 border-b border-amber-700 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <Award className="h-5 w-5 text-amber-400" />
                <div>
                  <div className="text-sm font-bold text-amber-200">Level {level} Warrior</div>
                  <div className="text-xs text-amber-400">{xp}/1000 XP</div>
                </div>
              </div>
              <Button variant="ghost" size="icon" className="h-8 w-8 text-amber-400" onClick={onToggle}>
                <X className="h-4 w-4" />
              </Button>
            </div>

            <div className="p-3 space-y-2">
              <h3 className="text-xs uppercase tracking-wider text-amber-500 font-bold flex items-center gap-2">
                <TrendingUp className="h-3 w-3" />
                Active Quests
              </h3>
              {tasks.map((task, index) => {
                const Icon = task.icon
                const isCompleted = completedCount.includes(task.id)
                const xpReward = Math.floor(30 + task.progress / 2)

                return (
                  <motion.div
                    key={task.id}
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: 0.05 * index }}
                    className={`p-3 rounded-xl bg-amber-900/30 border-2 ${
                      isCompleted ? "border-green-600 opacity-50" : "border-amber-700"
                    }`}
                  >
                    <div className="flex items-start gap-3">
                      <div className="w-10 h-10 rounded-lg bg-amber-800 border-2 border-amber-600 flex items-center justify-center">
                        <Icon className="h-5 w-5 text-amber-300" />
                      </div>

                      <div className="flex-1">
                        <p className="text-sm font-medium text-amber-100 text-balance">{task.title}</p>
                        <div className="flex items-center gap-2 mt-1">
                          <Zap className="h-3 w-3 text-amber-400 fill-amber-400" />
                          <span className="text-xs text-amber-400 font-bold">+{xpReward} XP</span>
                        </div>
                      </div>

                      {!isCompleted && (
                        <Button
                          size="sm"
                          className="bg-amber-600 hover:bg-amber-500 text-amber-950 font-bold"
                          onClick={() => handleComplete(task.id, xpReward)}
                        >
                          <Check className="h-4 w-4" />
                        </Button>
                      )}
                    </div>
                  </motion.div>
                )
              })}
            </div>

            <div className="p-3 bg-amber-900/30 border-t border-amber-700">
              <div className="h-2 bg-amber-950 rounded-full overflow-hidden">
                <motion.div
                  className="h-full bg-gradient-to-r from-amber-500 to-orange-500"
                  initial={{ width: 0 }}
                  animate={{ width: `${(xp / 1000) * 100}%` }}
                />
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
