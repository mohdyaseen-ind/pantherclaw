import { useQuery } from "@tanstack/react-query";
import { supabase } from "./supabase";
import { products as fallbackData } from "./data";

export const formatPrice = (n) =>
  "₹" + Number(n).toLocaleString("en-IN");

// Utility to mock delay if we fallback to local data
const delay = (ms) => new Promise((res) => setTimeout(res, ms));

export function useProducts(category = null) {
  return useQuery({
    queryKey: ["products", category],
    queryFn: async () => {
      // Use the highly optimized Materialized View to get the catalog instantly
      let query = supabase.from("mv_shop_catalog").select("*");
      
      if (category) {
        // category_name comes from the materialized view join
        query = query.eq("category_name", category);
      }
      
      const { data, error } = await query;
      
      // If we don't have Supabase wired up with tables yet, fallback to dummy data
      if (error || !data || data.length === 0) {
        console.warn("Falling back to local data (Supabase empty or error)", error);
        await delay(600); // Simulate network
        if (category) return fallbackData.filter((p) => p.category === category);
        return fallbackData;
      }

      return data;
    },
  });
}

export function useProduct(slug) {
  return useQuery({
    queryKey: ["product", slug],
    queryFn: async () => {
      // Fetch from the materialized view which already has variants joined
      const { data, error } = await supabase
        .from("mv_shop_catalog")
        .select("*")
        .eq("slug", slug)
        .single();
        
      if (error || !data) {
        console.warn("Falling back to local data", error);
        await delay(400);
        return fallbackData.find((p) => p.slug === slug);
      }
      
      return data;
    },
    enabled: !!slug,
  });
}

export async function subscribeNewsletter(email) {
  const { data, error } = await supabase.from("subscribers").insert([{ email }]);
  if (error) throw error;
  return data;
}

// Set up Supabase Realtime to invalidate React Query cache on database changes
export function setupRealtimeSubscriptions(queryClient) {
  supabase
    .channel("custom-all-channel")
    .on(
      "postgres_changes",
      { event: "*", schema: "public", table: "products" },
      (payload) => {
        console.log("Change received on products!", payload);
        queryClient.invalidateQueries({ queryKey: ["products"] });
        queryClient.invalidateQueries({ queryKey: ["product"] });
      }
    )
    .on(
      "postgres_changes",
      { event: "*", schema: "public", table: "product_variants" },
      (payload) => {
        console.log("Change received on variants!", payload);
        queryClient.invalidateQueries({ queryKey: ["products"] });
        queryClient.invalidateQueries({ queryKey: ["product"] });
      }
    )
    .subscribe();
}
