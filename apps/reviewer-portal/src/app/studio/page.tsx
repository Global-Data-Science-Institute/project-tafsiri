import { notFound } from "next/navigation";
import Studio from "@/components/studio/workspace";
import "./studio.css";
export const metadata = { title: "Tafsiri | Research workspace" };
export default async function StudioPage({
  searchParams,
}: {
  searchParams: Promise<{ invite?: string }>;
}) {
  if (process.env.DATA_STUDIO_ENABLED !== "synthetic") notFound();
  return <Studio invitation={(await searchParams).invite ?? ""} />;
}
