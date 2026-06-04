import React from "react";
import { useParams } from "react-router-dom";
import { useCartStore } from "../store/cartStore";
import { useProduct, formatPrice } from "../lib/api";

export default function ProductDetail() {
  const { slug } = useParams();
  const { addItem } = useCartStore();
  const { data: product, isLoading } = useProduct(slug);

  if (isLoading) {
    return (
      <div className="pt-28 px-4 sm:px-6 md:px-12 max-w-[1600px] mx-auto min-h-screen flex flex-col md:flex-row gap-10">
        <div className="flex-1 bg-line animate-pulse aspect-[3/4]" />
        <div className="flex-1 space-y-4">
          <div className="h-10 w-3/4 bg-line animate-pulse" />
          <div className="h-6 w-1/4 bg-line animate-pulse" />
          <div className="h-8 w-1/3 bg-line animate-pulse mt-10" />
        </div>
      </div>
    );
  }

  if (!product) {
    return <div className="pt-28 px-6 text-center text-xl">Product not found.</div>;
  }

  return (
    <div className="pt-28 px-4 sm:px-6 md:px-12 max-w-[1600px] mx-auto min-h-screen flex flex-col md:flex-row gap-10">
      <div className="flex-1 bg-bone aspect-[3/4]" style={{ viewTransitionName: `product-${product.slug}` }}>
        <img src={product.images[0]} alt={product.name} className="w-full h-full object-cover" />
      </div>
      <div className="flex-1">
        <h1 className="font-serif text-4xl mb-2">{product.name}</h1>
        <p className="text-ash mb-6">{product.subtitle}</p>
        <p className="font-sans text-xl mb-10">{formatPrice(product.price)}</p>
        <button 
          onClick={() => {
            const defaultVariant = product.variants?.[0];
            addItem(product, defaultVariant?.size || "M", defaultVariant?.id);
          }}
          className="bg-ink text-smoke px-8 py-4 label w-full hover:bg-[#262626] transition-colors"
        >
          Add to Cart
        </button>
      </div>
    </div>
  );
}
