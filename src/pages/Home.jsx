import React from "react";
import { Link } from "react-router-dom";
import { motion } from "framer-motion";
import ProductCard from "../components/ProductCard";
import { useProducts } from "../lib/api";

const fadeUp = {
  hidden: { opacity: 0, y: 40 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.8, ease: [0.16, 1, 0.3, 1] } }
};

const staggerContainer = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.15 }
  }
};

export default function Home() {
  const { data: allProducts, isLoading } = useProducts();
  const featured = allProducts ? allProducts.slice(0, 4) : [];

  return (
    <div data-testid="home-page" className="w-full bg-black pb-20">
      {/* 1. Hero Section */}
      <section className="w-full mb-1">
        <Link to="/shop" className="group block cursor-pointer">
          <div className="w-full h-[75vh] md:h-[100vh] overflow-hidden bg-[#111]">
            <img 
              src="/images/image.png" 
              alt="Spring Drop" 
              className="w-full h-full object-cover object-[center_30%]" 
              fetchpriority="high" 
            />
          </div>
          <div className="sticky bottom-0 z-10 w-full py-4 px-4 sm:px-6 md:px-8 flex items-center justify-between bg-black text-white border-b border-[#222]">
            <span className="text-sm font-medium tracking-wider uppercase">Spring Drop 01</span>
            <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="transition-transform group-hover:translate-x-1">
              <path d="M5 12h14"></path>
              <path d="m12 5 7 7-7 7"></path>
            </svg>
          </div>
        </Link>
      </section>

      {/* 2. 50/50 Split Banners */}
      <section className="w-full grid grid-cols-1 md:grid-cols-2 gap-y-1 md:gap-x-1 mb-20">
        <Link to="/shop?category=Women" className="group block cursor-pointer">
          <div className="w-full aspect-[3/4] overflow-hidden bg-[#111]">
            <img 
              src="/images/Gemini_Generated_Image_t1txt2t1txt2t1tx (1)-clean.png" 
              alt="Women" 
              className="w-full h-full object-cover" 
              loading="lazy" 
            />
          </div>
          <div className="w-full py-4 px-4 sm:px-6 md:px-8 flex items-center justify-between bg-black text-white">
            <span className="text-sm font-medium tracking-wider uppercase">Women</span>
            <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="transition-transform group-hover:translate-x-1">
              <path d="M5 12h14"></path>
              <path d="m12 5 7 7-7 7"></path>
            </svg>
          </div>
        </Link>
        <Link to="/shop?category=Men" className="group block cursor-pointer">
          <div className="w-full aspect-[3/4] overflow-hidden bg-[#111]">
            <img 
              src="/images/Gemini_Generated_Image_qepdsvqepdsvqepd-clean.png" 
              alt="Men" 
              className="w-full h-full object-cover" 
              loading="lazy" 
            />
          </div>
          <div className="w-full py-4 px-4 sm:px-6 md:px-8 flex items-center justify-between bg-black text-white">
            <span className="text-sm font-medium tracking-wider uppercase">Men</span>
            <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="transition-transform group-hover:translate-x-1">
              <path d="M5 12h14"></path>
              <path d="m12 5 7 7-7 7"></path>
            </svg>
          </div>
        </Link>
      </section>

      {/* 3. Featured Products */}
      <motion.section 
        initial="hidden" whileInView="visible" viewport={{ once: true, amount: 0.1 }}
        className="mx-auto max-w-[1600px] px-4 sm:px-6 md:px-12" data-testid="featured-section"
      >
        <motion.div variants={fadeUp} className="mb-10 flex flex-col items-center justify-center gap-4">
          <h2 className="text-2xl font-medium tracking-widest uppercase text-white">New Arrivals</h2>
        </motion.div>
        <motion.div variants={staggerContainer} className="grid grid-cols-2 gap-x-4 gap-y-12 md:grid-cols-4">
          {isLoading ? (
            Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="aspect-[3/4] w-full animate-pulse bg-[#111]" />
            ))
          ) : (
            featured.map((product) => (
              <motion.div variants={fadeUp} key={product.slug}>
                <ProductCard product={product} />
              </motion.div>
            ))
          )}
        </motion.div>
        
        <div className="mt-12 flex justify-center">
           <Link to="/shop" className="text-sm font-medium tracking-widest uppercase border-b border-white pb-1 text-white hover:text-white/60 hover:border-white/60 transition-colors">
              View All Products
           </Link>
        </div>
      </motion.section>
    </div>
  );
}
