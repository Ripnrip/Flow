/** @type {import('next').NextConfig} */
const nextConfig = {
  typescript: {
    ignoreBuildErrors: true,
  },
  images: {
    unoptimized: true,
  },
  experimental: {
    // Allows next/font/google to resolve on Vercel without TLS issues
    turbopackUseSystemTlsCerts: true,
  },
}

export default nextConfig
