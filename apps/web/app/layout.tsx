import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({ variable: "--font-geist-sans", subsets: ["latin"] });
const geistMono = Geist_Mono({ variable: "--font-geist-mono", subsets: ["latin"] });

export const metadata: Metadata = {
  metadataBase: new URL("https://ai-limits.xusbadia.chatgpt.site"),
  title: "AI Limits — Your AI usage at a glance",
  description: "See Codex and Claude usage, reset times, and remaining capacity from one private iPhone dashboard.",
  openGraph: {
    title: "AI Limits — Know before you hit the limit",
    description: "Codex and Claude usage in one private iPhone dashboard.",
    type: "website",
    images: ["/social-card.png"],
  },
  icons: { icon: "/favicon.svg", shortcut: "/favicon.svg" },
};

export const viewport: Viewport = { themeColor: "#f4f4ef", colorScheme: "light" };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body className={`${geistSans.variable} ${geistMono.variable}`}>{children}</body></html>;
}
