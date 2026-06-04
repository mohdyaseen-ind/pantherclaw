import React from "react";
import { Link } from "react-router-dom";
import { formatPrice } from "../lib/api";

export default function ProductCard({ product, index = 0 }) {
  return (
    <Link
      to={`/product/${product.slug}`}
      data-testid={`product-card-${product.slug}`}
      className="group block"
    >
      <div className="relative aspect-[3/4] overflow-hidden bg-bone" style={{ viewTransitionName: `product-${product.slug}` }}>
        <img
          src={product.images[0]}
          alt={product.name}
          loading="lazy"
          className="img-zoom h-full w-full object-cover"
        />
        {product.images[1] && (
          <img
            src={product.images[1]}
            alt={`${product.name} alternate`}
            loading="lazy"
            className="absolute inset-0 h-full w-full object-cover opacity-0 transition-opacity duration-700 group-hover:opacity-100"
          />
        )}
        {product.badge && (
          <span className="label absolute left-4 top-4 bg-ink px-3 py-1.5 text-[0.6rem] text-smoke">
            {product.badge}
          </span>
        )}
        <span className="label absolute bottom-4 left-1/2 -translate-x-1/2 translate-y-4 whitespace-nowrap bg-smoke px-5 py-2.5 text-[0.62rem] text-ink opacity-0 transition-all duration-500 group-hover:translate-y-0 group-hover:opacity-100">
          View Product
        </span>
      </div>
      <div className="mt-4 flex items-start justify-between gap-3">
        <div>
          <h3 className="font-sans text-sm font-semibold tracking-tight">{product.name}</h3>
          <p className="mt-0.5 text-xs text-ash">{product.subtitle} · {product.fit}</p>
        </div>
        <span className="font-sans text-sm font-medium">{formatPrice(product.price)}</span>
      </div>
    </Link>
  );
}
