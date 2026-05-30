"use client"

import { useState } from "react"
import { DynamicIsland } from "@/components/dynamic-island"
import { ZenIsland } from "@/components/zen-island"
import { GamifiedIsland } from "@/components/gamified-island"
import { GardenIsland } from "@/components/garden-island"
import { HolographicIsland } from "@/components/holographic-island"
import { StickyIsland } from "@/components/sticky-island"
import { TimelineIsland } from "@/components/timeline-island"
import { AlcoveIsland } from "@/components/alcove-island"
import { Button } from "@/components/ui/button"
import { CheckCircle, Calendar, ListTodo, FileText } from "lucide-react"

export default function Home() {
  const [activeConceptIndex, setActiveConceptIndex] = useState(0)
  const [isExpanded, setIsExpanded] = useState(false)

  const sampleTasks = [
    { id: 1, title: "Review Q4 presentation", source: "Apple Reminders", progress: 75, icon: FileText },
    { id: 2, title: "Team standup at 10am", source: "Calendar", progress: 0, icon: Calendar },
    { id: 3, title: "Update project roadmap", source: "Trello", progress: 40, icon: ListTodo },
    { id: 4, title: "Client feedback review", source: "Todoist", progress: 90, icon: CheckCircle },
  ]

  const concepts = [
    {
      id: 1,
      name: "Sleek Modern",
      description: "Elegant gradient design with smooth animations",
      component: DynamicIsland,
    },
    {
      id: 2,
      name: "Zen Focus",
      description: "Minimalist breathing interface, one task at a time",
      component: ZenIsland,
    },
    {
      id: 3,
      name: "Quest Mode",
      description: "Gamified RPG experience with XP and achievements",
      component: GamifiedIsland,
    },
    {
      id: 4,
      name: "Living Garden",
      description: "Nature-inspired growth as you complete tasks",
      component: GardenIsland,
    },
    {
      id: 5,
      name: "Holographic",
      description: "Futuristic sci-fi interface with particle effects",
      component: HolographicIsland,
    },
    {
      id: 6,
      name: "Sticky Board",
      description: "Physical sticky notes with drag-and-drop",
      component: StickyIsland,
    },
    {
      id: 7,
      name: "Timeline",
      description: "Time-based visualization with urgency indicators",
      component: TimelineIsland,
    },
    {
      id: 8,
      name: "Alcove",
      description: "Dynamic Island for Mac — Music, Calendar, and HUD",
      component: AlcoveIsland,
    },
  ]

  const ActiveIsland = concepts[activeConceptIndex].component

  return (
    <main className="relative min-h-screen bg-gradient-to-b from-[#0a0a0a] via-[#111111] to-[#0a0a0a] overflow-hidden">
      {/* Ambient background effects */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-blue-500/5 rounded-full blur-3xl animate-pulse" />
        <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-purple-500/5 rounded-full blur-3xl animate-pulse [animation-delay:1s]" />
      </div>

      {/* Dynamic Island Component */}
      <ActiveIsland isExpanded={isExpanded} onToggle={() => setIsExpanded(!isExpanded)} tasks={sampleTasks} />

      {/* Content Section */}
      <div className="relative z-0 container mx-auto px-4 pt-32 pb-16">
        <div className="max-w-4xl mx-auto space-y-16">
          {/* Hero Section */}
          <section className="text-center space-y-6">
            <h1 className="text-5xl md:text-7xl font-bold text-white text-balance leading-tight">
              Your productivity,
              <br />
              <span className="text-transparent bg-clip-text bg-gradient-to-r from-blue-400 via-purple-400 to-pink-400">
                always at hand
              </span>
            </h1>
            <p className="text-xl text-zinc-400 max-w-2xl mx-auto text-pretty">
              Explore 8 unique concepts for a Dynamic Island productivity extension. Each brings a different personality
              to your task management experience.
            </p>
          </section>

          {/* Concept Selector */}
          <section className="space-y-6">
            <h2 className="text-2xl font-bold text-white text-center">Choose a concept</h2>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {concepts.map((concept, index) => (
                <button
                  key={concept.id}
                  onClick={() => {
                    setActiveConceptIndex(index)
                    setIsExpanded(false)
                  }}
                  className={`p-4 rounded-xl border transition-all ${
                    activeConceptIndex === index
                      ? "bg-zinc-800 border-zinc-600 shadow-lg"
                      : "bg-zinc-900/30 border-zinc-800/50 hover:bg-zinc-900/50"
                  }`}
                >
                  <div className="text-left space-y-2">
                    <div className="flex items-center gap-2">
                      <div
                        className={`w-2 h-2 rounded-full ${activeConceptIndex === index ? "bg-blue-400" : "bg-zinc-700"}`}
                      />
                      <h3 className="text-sm font-semibold text-white">{concept.name}</h3>
                    </div>
                    <p className="text-xs text-zinc-500 text-pretty">{concept.description}</p>
                  </div>
                </button>
              ))}
            </div>
          </section>

          {/* Current Concept Info */}
          <section className="text-center space-y-4">
            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-zinc-900/50 border border-zinc-800">
              <span className="text-xs text-zinc-500">Now viewing:</span>
              <span className="text-sm font-semibold text-white">{concepts[activeConceptIndex].name}</span>
            </div>
            <div className="flex items-center justify-center gap-4">
              <Button
                size="lg"
                className="bg-white text-black hover:bg-zinc-200"
                onClick={() => setIsExpanded(!isExpanded)}
              >
                {isExpanded ? "Collapse" : "Expand"} concept
              </Button>
            </div>
          </section>

          {/* Integration Badges */}
          <section className="space-y-6">
            <h3 className="text-xl font-semibold text-white text-center">Integrates with your tools</h3>
            <div className="flex flex-wrap items-center justify-center gap-4">
              {["Apple Reminders", "Calendar", "Todoist", "Trello"].map((tool) => (
                <div
                  key={tool}
                  className="px-6 py-3 rounded-full bg-zinc-900/50 border border-zinc-800 text-zinc-400 text-sm font-medium"
                >
                  {tool}
                </div>
              ))}
            </div>
          </section>
        </div>
      </div>
    </main>
  )
}
