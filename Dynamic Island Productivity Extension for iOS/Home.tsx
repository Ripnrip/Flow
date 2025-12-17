import { DynamicIsland, IslandTheme } from "@/components/DynamicIsland";
import { Button } from "@/components/ui/button";
import { motion } from "framer-motion";
import { ArrowRight, CheckCircle2, Layers, Zap, Palette } from "lucide-react";
import { useState } from "react";
import { cn } from "@/lib/utils";

const themes: { id: IslandTheme; label: string; description: string; color: string }[] = [
  { id: "ethereal", label: "Ethereal", description: "Calm, flow-state, weightless.", color: "bg-focus-purple" },
  { id: "neobrutalism", label: "Neo-Brutalism", description: "Bold, loud, unapologetic.", color: "bg-[#CCFF00]" },
  { id: "cyberpunk", label: "Cyberpunk", description: "High-tech, dystopian, data-driven.", color: "bg-cyan-500" },
  { id: "clay", label: "Soft Clay", description: "Friendly, tactile, playful.", color: "bg-pink-400" },
  { id: "pixel", label: "Retro Pixel", description: "Nostalgic, arcade, 8-bit.", color: "bg-[#8bac0f]" },
  { id: "glass", label: "Frosted Glass", description: "Premium, icy, modern iOS.", color: "bg-blue-200" },
  { id: "organic", label: "Organic Nature", description: "Grounded, peaceful, eco-friendly.", color: "bg-[#8F9779]" },
  { id: "industrial", label: "Industrial Tech", description: "Precision, engineering, blueprint.", color: "bg-orange-500" },
  { id: "popart", label: "Pop Art", description: "Energetic, comic book, expressive.", color: "bg-yellow-400" },
  { id: "ink", label: "Zen Ink", description: "Minimalist, traditional, artistic.", color: "bg-black" },
];

export default function Home() {
  const [islandState, setIslandState] = useState<"idle" | "active" | "minimal" | "notask">("idle");
  const [currentTheme, setCurrentTheme] = useState<IslandTheme>("ethereal");

  return (
    <div className="min-h-screen bg-background text-foreground font-sans selection:bg-focus-purple/20 transition-colors duration-500">
      {/* Hero Section */}
      <section className="relative min-h-screen flex flex-col items-center justify-center overflow-hidden pt-20">
        {/* Background Assets */}
        <div className="absolute inset-0 z-0">
          <img
            src="/images/hero-background.png"
            alt="Ethereal Background"
            className={cn(
              "w-full h-full object-cover transition-opacity duration-700",
              currentTheme === "ethereal" ? "opacity-80" : "opacity-20 blur-xl"
            )}
          />
          <div className="absolute inset-0 bg-gradient-to-b from-transparent via-background/50 to-background" />
        </div>

        {/* Dynamic Island Demo Container */}
        <div className="relative z-20 w-full max-w-md mx-auto mb-12 h-[200px] flex items-start justify-center">
          <DynamicIsland state={islandState} theme={currentTheme} onStateChange={setIslandState} />
        </div>

        {/* Hero Content */}
        <div className="relative z-10 container mx-auto px-4 text-center max-w-4xl">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, ease: "easeOut" }}
          >
            <h1 className="font-heading text-5xl md:text-7xl font-bold tracking-tight mb-6 text-foreground">
              Focus Flow
            </h1>
            <p className="text-xl md:text-2xl text-muted-foreground mb-8 max-w-2xl mx-auto leading-relaxed">
              Your always-available productivity companion. <br/>
              Currently viewing: <span className="text-foreground font-bold">{themes.find(t => t.id === currentTheme)?.label}</span>
            </p>
            
            <div className="flex flex-wrap justify-center gap-4 mb-12">
              <Button 
                size="lg" 
                className="rounded-full bg-primary hover:bg-primary/90 text-white px-8 h-12 text-base shadow-lg shadow-focus-purple/20"
                onClick={() => setIslandState("active")}
              >
                Try Demo
                <ArrowRight className="ml-2 w-4 h-4" />
              </Button>
              <Button 
                variant="outline" 
                size="lg" 
                className="rounded-full border-border bg-white/50 backdrop-blur-sm hover:bg-white/80 px-8 h-12 text-base"
                onClick={() => {
                  const states: ("idle" | "active" | "minimal" | "notask")[] = ["idle", "active", "minimal", "notask"];
                  const nextIndex = (states.indexOf(islandState) + 1) % states.length;
                  setIslandState(states[nextIndex]);
                }}
              >
                Cycle States
              </Button>
            </div>
          </motion.div>
        </div>

        {/* Theme Selector */}
        <div className="relative z-20 container mx-auto px-4 mb-24">
          <div className="flex flex-col items-center">
            <div className="flex items-center gap-2 mb-6 text-muted-foreground">
              <Palette className="w-4 h-4" />
              <span className="text-sm font-medium uppercase tracking-wider">Select Style Concept</span>
            </div>
            <div className="flex flex-wrap justify-center gap-3 max-w-3xl">
              {themes.map((theme) => (
                <button
                  key={theme.id}
                  onClick={() => setCurrentTheme(theme.id)}
                  className={cn(
                    "group relative flex items-center gap-2 px-4 py-2 rounded-full border transition-all duration-300",
                    currentTheme === theme.id 
                      ? "bg-white border-black/10 shadow-lg scale-105 ring-2 ring-offset-2 ring-focus-purple/50" 
                      : "bg-white/40 border-transparent hover:bg-white/80 hover:scale-105"
                  )}
                >
                  <div className={cn("w-3 h-3 rounded-full", theme.color)} />
                  <span className={cn(
                    "text-sm font-medium",
                    currentTheme === theme.id ? "text-foreground" : "text-muted-foreground"
                  )}>
                    {theme.label}
                  </span>
                </button>
              ))}
            </div>
            <p className="mt-6 text-sm text-muted-foreground italic">
              "{themes.find(t => t.id === currentTheme)?.description}"
            </p>
          </div>
        </div>

        {/* State Indicators */}
        <div className="absolute bottom-12 left-0 right-0 flex justify-center gap-8 z-10">
          {[
            { id: "idle", label: "Idle" },
            { id: "active", label: "Active" },
            { id: "minimal", label: "Minimal" },
            { id: "notask", label: "All Clear" },
          ].map((s) => (
            <button
              key={s.id}
              onClick={() => setIslandState(s.id as any)}
              className={`text-sm font-medium transition-all duration-300 ${
                islandState === s.id
                  ? "text-focus-purple scale-110"
                  : "text-muted-foreground hover:text-foreground"
              }`}
            >
              {s.label}
            </button>
          ))}
        </div>
      </section>

      {/* Features Grid */}
      <section className="py-24 relative z-10 bg-white/50 backdrop-blur-xl">
        <div className="container mx-auto px-4">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <FeatureCard
              icon={<Zap className="w-6 h-6 text-focus-purple" />}
              title="Instant Access"
              description="Your top task is always one tap away. No digging through apps, just pure focus."
            />
            <FeatureCard
              icon={<Layers className="w-6 h-6 text-focus-purple" />}
              title="Unified Hub"
              description="Syncs with Reminders, Calendar, Todoist, and Trello. One island to rule them all."
            />
            <FeatureCard
              icon={<CheckCircle2 className="w-6 h-6 text-focus-purple" />}
              title="Flow State"
              description="Designed to be non-intrusive. Gentle animations guide you back to what matters."
            />
          </div>
        </div>
      </section>
    </div>
  );
}

function FeatureCard({ icon, title, description }: { icon: React.ReactNode; title: string; description: string }) {
  return (
    <motion.div
      whileHover={{ y: -5 }}
      className="p-8 rounded-3xl bg-white border border-gray-100 shadow-sm hover:shadow-xl hover:shadow-focus-purple/10 transition-all duration-300"
    >
      <div className="w-12 h-12 rounded-2xl bg-focus-purple/10 flex items-center justify-center mb-6">
        {icon}
      </div>
      <h3 className="font-heading text-xl font-bold mb-3">{title}</h3>
      <p className="text-muted-foreground leading-relaxed">{description}</p>
    </motion.div>
  );
}
