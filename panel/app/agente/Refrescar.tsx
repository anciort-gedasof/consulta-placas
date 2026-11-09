"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

// Vuelve a pedir los avisos cada cierto tiempo, sin recargar la página.
export default function Refrescar({ segundos }: { segundos: number }) {
  const router = useRouter();
  useEffect(() => {
    const t = setInterval(() => router.refresh(), segundos * 1000);
    return () => clearInterval(t);
  }, [router, segundos]);
  return null;
}
