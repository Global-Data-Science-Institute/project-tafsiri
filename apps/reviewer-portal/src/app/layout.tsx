import type { Metadata } from "next";
import "./globals.css";
import "./auth.css";
export const metadata: Metadata = { title: "Project Tafsiri | GDSI Reviewer Portal", description: "Language review for Project Tafsiri, a Global Data Science Institute research initiative." };
export default function RootLayout({ children }: LayoutProps<"/">) {
  return <html lang="en"><body>{children}<footer className="site-footer">Global Data Science Institute · Project Tafsiri · <a href="https://www.gdsi.institute/">Return to GDSI</a></footer></body></html>;
}
