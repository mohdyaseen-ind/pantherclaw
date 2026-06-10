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
              src="/images/Gemini_Generated_Image_motm6wmotm6wmotm-clean.png" 
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
              src="images/Gemini_Generated_Image_evcefsevcefsevce-clean.png" 
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

      {/* 3. Full-Screen Gapless Flex */}
      <section className="w-full h-[100vh] flex flex-col bg-black overflow-hidden pt-[80px] pb-4">
        {/* Desktop: 2 Rows of 3 */}
        <div className="hidden md:flex flex-col h-full w-full justify-center min-h-0">
          <div className="flex h-1/2 justify-center items-center w-full min-h-0">
            {[
              "images/Gemini_Generated_Image_mbal2rmbal2rmbal (1)-clean.png",
              "/images/1000144719.png",
              "/images/1000144720.png",
            ].map((src, index) => (
              <Link key={index} to="/shop" className="h-full w-auto block cursor-pointer shrink-0">
                <img src={src} alt={`Product ${index + 1}`} className="h-full w-auto object-contain" loading="lazy" />
              </Link>
            ))}
          </div>
          <div className="flex h-1/2 justify-center items-center w-full min-h-0">
            {[
              "images/Gemini_Generated_Image_jtr8kcjtr8kcjtr8-clean.png",
              "images/Gemini_Generated_Image_n0b4ygn0b4ygn0b4-clean.png",
              "images/Gemini_Generated_Image_38zhne38zhne38zh-clean.png",
            ].map((src, index) => (
              <Link key={index} to="/shop" className="h-full w-auto block cursor-pointer shrink-0">
                <img src={src} alt={`Product ${index + 4}`} className="h-full w-auto object-contain" loading="lazy" />
              </Link>
            ))}
          </div>
        </div>

        {/* Mobile: 3 Rows of 2 */}
        <div className="flex md:hidden flex-col h-full w-full justify-center min-h-0">
          <div className="flex h-1/3 justify-center items-center w-full min-h-0">
            {["/images/1000144708.png", "/images/1000144719.png"].map((src, index) => (
              <Link key={index} to="/shop" className="h-full w-auto block cursor-pointer shrink-0">
                <img src={src} alt={`Product`} className="h-full w-auto object-contain" loading="lazy" />
              </Link>
            ))}
          </div>
          <div className="flex h-1/3 justify-center items-center w-full min-h-0">
            {["/images/1000144720.png", "/images/1000150020.png"].map((src, index) => (
              <Link key={index} to="/shop" className="h-full w-auto block cursor-pointer shrink-0">
                <img src={src} alt={`Product`} className="h-full w-auto object-contain" loading="lazy" />
              </Link>
            ))}
          </div>
          <div className="flex h-1/3 justify-center items-center w-full min-h-0">
            {["/images/1000150765.png", "/images/1000150766.png"].map((src, index) => (
              <Link key={index} to="/shop" className="h-full w-auto block cursor-pointer shrink-0">
                <img src={src} alt={`Product`} className="h-full w-auto object-contain" loading="lazy" />
              </Link>
            ))}
          </div>
        </div>
      </section>
    </div>
  );
}
