import { AnimatePresence, motion } from "framer-motion";
import { Check, Clock, Waves, Zap, Terminal, Leaf, Paintbrush, Gamepad2, Box } from "lucide-react";
import { useEffect, useState } from "react";
import { cn } from "@/lib/utils";

export type IslandState = "idle" | "active" | "minimal" | "notask";
export type IslandTheme = 
  | "ethereal" 
  | "neobrutalism" 
  | "cyberpunk" 
  | "clay" 
  | "pixel" 
  | "glass" 
  | "organic" 
  | "industrial" 
  | "popart" 
  | "ink";

interface DynamicIslandProps {
  state: IslandState;
  theme: IslandTheme;
  onStateChange?: (newState: IslandState) => void;
}

export function DynamicIsland({ state, theme, onStateChange }: DynamicIslandProps) {
  const [isExpanded, setIsExpanded] = useState(false);
  const [progress, setProgress] = useState(65);

  useEffect(() => {
    if (state !== "active") {
      setIsExpanded(false);
    } else {
      setIsExpanded(true);
    }
  }, [state]);

  const handleTouchStart = () => {
    if (state === "idle" || state === "minimal") {
      const timer = setTimeout(() => {
        onStateChange?.("active");
      }, 300);
      return () => clearTimeout(timer);
    }
  };

  const handleTap = () => {
    if (state === "active") {
      onStateChange?.("idle");
    }
  };

  // Theme-specific configurations
  const themeConfig = {
    ethereal: {
      container: "bg-black/90 backdrop-blur-xl shadow-2xl shadow-focus-purple/20",
      text: "font-sans text-white",
      accent: "bg-focus-purple",
      icon: <img src="/images/app-icon-concept.png" alt="Icon" className="w-full h-full object-cover rounded-full" />,
      spring: { stiffness: 300, damping: 25 }
    },
    neobrutalism: {
      container: "bg-white border-4 border-black shadow-[4px_4px_0px_0px_rgba(0,0,0,1)]",
      text: "font-grotesk text-black font-bold uppercase tracking-tighter",
      accent: "bg-[#CCFF00]",
      icon: <div className="w-full h-full bg-black flex items-center justify-center text-[#CCFF00]"><Zap size={14} fill="currentColor" /></div>,
      spring: { stiffness: 500, damping: 15 }
    },
    cyberpunk: {
      container: "bg-black border border-cyan-500 shadow-[0_0_15px_rgba(6,182,212,0.5)]",
      text: "font-mono text-cyan-400 drop-shadow-[0_0_5px_rgba(6,182,212,0.8)]",
      accent: "bg-magenta-500",
      icon: <div className="w-full h-full bg-black border border-cyan-500 flex items-center justify-center text-cyan-500"><Terminal size={14} /></div>,
      spring: { stiffness: 400, damping: 20, mass: 0.5 }
    },
    clay: {
      container: "bg-blue-300 shadow-[inset_-4px_-4px_10px_rgba(0,0,0,0.2),inset_4px_4px_10px_rgba(255,255,255,0.5),8px_8px_20px_rgba(0,0,0,0.1)]",
      text: "font-round text-white font-bold",
      accent: "bg-pink-400",
      icon: <div className="w-full h-full bg-white rounded-full flex items-center justify-center text-blue-400"><Box size={14} /></div>,
      spring: { stiffness: 200, damping: 10 }
    },
    pixel: {
      container: "bg-[#0f380f] border-4 border-[#8bac0f] shadow-none",
      text: "font-pixel text-[#9bbc0f] text-[8px] leading-tight",
      accent: "bg-[#8bac0f]",
      icon: <div className="w-full h-full bg-[#306230] flex items-center justify-center text-[#9bbc0f]"><Gamepad2 size={12} /></div>,
      spring: { duration: 0.2, ease: "linear" } as any // Stepped animation simulation
    },
    glass: {
      container: "bg-white/10 backdrop-blur-md border border-white/20 shadow-xl",
      text: "font-sans text-white font-medium",
      accent: "bg-white/30",
      icon: <div className="w-full h-full bg-white/20 backdrop-blur-sm rounded-full flex items-center justify-center text-white"><Waves size={14} /></div>,
      spring: { stiffness: 250, damping: 30 }
    },
    organic: {
      container: "bg-[#E8E4D9] shadow-lg rounded-[30px]",
      text: "font-serif text-[#4A4A4A] italic",
      accent: "bg-[#8F9779]",
      icon: <div className="w-full h-full bg-[#8F9779] rounded-full flex items-center justify-center text-[#E8E4D9]"><Leaf size={14} /></div>,
      spring: { stiffness: 150, damping: 20 }
    },
    industrial: {
      container: "bg-[#2A2A2A] border-t-2 border-orange-500 shadow-md",
      text: "font-mono text-gray-300 uppercase tracking-widest text-[10px]",
      accent: "bg-orange-500",
      icon: <div className="w-full h-full bg-orange-500 flex items-center justify-center text-black font-bold">01</div>,
      spring: { stiffness: 800, damping: 40 }
    },
    popart: {
      container: "bg-yellow-400 border-4 border-black shadow-[6px_6px_0px_black]",
      text: "font-comic text-black text-lg tracking-wide",
      accent: "bg-red-500",
      icon: <div className="w-full h-full bg-blue-500 border-2 border-black flex items-center justify-center text-white"><Zap size={14} /></div>,
      spring: { stiffness: 600, damping: 12 }
    },
    ink: {
      container: "bg-white border-2 border-black rounded-sm shadow-sm",
      text: "font-ink text-black",
      accent: "bg-black",
      icon: <div className="w-full h-full bg-black rounded-full flex items-center justify-center text-white"><Paintbrush size={12} /></div>,
      spring: { stiffness: 200, damping: 35 }
    }
  };

  const currentTheme = themeConfig[theme];

  const variants = {
    idle: {
      width: 200,
      height: 35,
      borderRadius: theme === "neobrutalism" || theme === "pixel" || theme === "industrial" || theme === "popart" || theme === "ink" ? 4 : 20,
    },
    minimal: {
      width: 50,
      height: 35,
      borderRadius: theme === "neobrutalism" || theme === "pixel" || theme === "industrial" || theme === "popart" || theme === "ink" ? 4 : 20,
    },
    active: {
      width: 360,
      height: 180,
      borderRadius: theme === "neobrutalism" || theme === "pixel" || theme === "industrial" || theme === "popart" || theme === "ink" ? 8 : 40,
    },
    notask: {
      width: 200,
      height: 35,
      borderRadius: theme === "neobrutalism" || theme === "pixel" || theme === "industrial" || theme === "popart" || theme === "ink" ? 4 : 20,
    },
  };

  return (
    <div className="flex justify-center items-start pt-4 w-full h-full relative z-50">
      <motion.div
        layout
        initial="idle"
        animate={state}
        variants={variants}
        transition={currentTheme.spring}
        className={cn(
          "overflow-hidden relative cursor-pointer transition-colors duration-500",
          currentTheme.container
        )}
        onMouseDown={handleTouchStart}
        onClick={handleTap}
      >
        {/* TrueDepth Camera Placeholder - Hidden in some themes for aesthetic */}
        {theme !== "pixel" && theme !== "neobrutalism" && theme !== "popart" && (
          <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[100px] h-[35px] z-0 pointer-events-none opacity-0" />
        )}

        <AnimatePresence mode="wait">
          {state === "idle" && (
            <motion.div
              key="idle"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className={cn("flex justify-between items-center w-full h-full px-4 relative z-10", currentTheme.text)}
            >
              <div className="flex items-center gap-2">
                <div className="relative w-6 h-6">
                  <div className={cn("w-full h-full flex items-center justify-center overflow-hidden", theme === "neobrutalism" || theme === "pixel" ? "rounded-none" : "rounded-full")}>
                    {currentTheme.icon}
                  </div>
                  {theme === "ethereal" && (
                    <motion.div
                      animate={{ scale: [1, 1.4, 1], opacity: [0.5, 0, 0.5] }}
                      transition={{ duration: 3, repeat: Infinity }}
                      className="absolute inset-0 rounded-full border border-focus-purple"
                    />
                  )}
                </div>
              </div>
              <span className="text-[10px] opacity-90">Due 10:30</span>
            </motion.div>
          )}

          {state === "minimal" && (
            <motion.div
              key="minimal"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className={cn("flex justify-center items-center w-full h-full relative z-10", currentTheme.text)}
            >
              <div className={cn("w-6 h-6 flex items-center justify-center text-[10px] font-bold", theme === "neobrutalism" || theme === "pixel" ? "rounded-none" : "rounded-full", currentTheme.accent, theme === "neobrutalism" ? "text-black" : "text-white")}>
                3
              </div>
            </motion.div>
          )}

          {state === "notask" && (
            <motion.div
              key="notask"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className={cn("flex justify-between items-center w-full h-full px-4 relative z-10", currentTheme.text)}
            >
              <div className="flex items-center gap-2">
                <Waves className="w-4 h-4 opacity-50 animate-pulse" />
              </div>
              <span className="text-[10px] opacity-50">All Clear</span>
            </motion.div>
          )}

          {state === "active" && (
            <motion.div
              key="active"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 10 }}
              transition={{ delay: 0.1 }}
              className={cn("flex flex-col w-full h-full p-6 relative z-10", currentTheme.text)}
            >
              <div className="flex justify-between items-start mb-4">
                <div className="flex items-center gap-3">
                  <div className={cn("w-10 h-10 flex items-center justify-center overflow-hidden", theme === "neobrutalism" || theme === "pixel" ? "rounded-none" : "rounded-full")}>
                     {currentTheme.icon}
                  </div>
                  <div>
                    <h3 className="text-sm font-bold opacity-90">Draft Q3 Report</h3>
                    <p className="text-[10px] opacity-60">Focus Flow • Priority 1</p>
                  </div>
                </div>
                <span className="text-[10px] opacity-60">10:30 AM</span>
              </div>

              <div className={cn("w-full h-1.5 mb-6 overflow-hidden", theme === "neobrutalism" || theme === "pixel" ? "rounded-none bg-black/10" : "rounded-full bg-white/10")}>
                <motion.div
                  initial={{ width: 0 }}
                  animate={{ width: `${progress}%` }}
                  className={cn("h-full", currentTheme.accent)}
                />
              </div>

              <div className="flex gap-3 mt-auto">
                <button
                  className={cn(
                    "flex-1 h-10 flex items-center justify-center gap-2 transition-colors",
                    theme === "neobrutalism" || theme === "pixel" ? "rounded-none border-2 border-black bg-white hover:bg-gray-100 text-black" : "rounded-full bg-white/10 hover:bg-white/20"
                  )}
                  onClick={(e) => {
                    e.stopPropagation();
                    onStateChange?.("idle");
                  }}
                >
                  <Clock className="w-4 h-4" />
                  <span className="text-xs font-medium">Snooze</span>
                </button>
                <button
                  className={cn(
                    "flex-1 h-10 flex items-center justify-center gap-2 transition-colors",
                    theme === "neobrutalism" || theme === "pixel" ? "rounded-none border-2 border-black bg-black text-white hover:bg-gray-800" : "rounded-full text-white",
                    theme !== "neobrutalism" && theme !== "pixel" && currentTheme.accent
                  )}
                  onClick={(e) => {
                    e.stopPropagation();
                    setProgress(100);
                    setTimeout(() => onStateChange?.("notask"), 600);
                  }}
                >
                  <Check className="w-4 h-4" />
                  <span className="text-xs font-medium">Done</span>
                </button>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </motion.div>
    </div>
  );
}
