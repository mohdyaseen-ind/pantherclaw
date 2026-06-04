import React, { useRef } from "react";
import { Link } from "react-router-dom";
import { motion, useScroll, useTransform } from "framer-motion";
import Marquee from "../components/Marquee";
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
  const heroRef = useRef(null);
  const editorialRef = useRef(null);
  const quoteRef = useRef(null);

  const { scrollYProgress: heroScroll } = useScroll({ target: heroRef, offset: ["start start", "end start"] });
  const heroY = useTransform(heroScroll, [0, 1], ["0%", "30%"]);

  const { scrollYProgress: editorialScroll } = useScroll({ target: editorialRef, offset: ["start end", "end start"] });
  const editorialY = useTransform(editorialScroll, [0, 1], ["-15%", "15%"]);

  const { scrollYProgress: quoteScroll } = useScroll({ target: quoteRef, offset: ["start end", "end start"] });
  const quoteY = useTransform(quoteScroll, [0, 1], ["-15%", "15%"]);

  const { data: allProducts, isLoading } = useProducts();
  const featured = allProducts ? allProducts.slice(0, 4) : [];

  return (
    <div data-testid="home-page">
      {/* 1. Hero Section */}
      <section ref={heroRef} className="relative h-[100svh] w-full overflow-hidden bg-[#d8d8d8]">
        <motion.div style={{ y: heroY }} className="absolute inset-0 h-[120%] -top-[10%] w-full">
          <img src="/images/img5.jpeg" alt="PantherClaw denim editorial" className="h-full w-full object-cover object-center" fetchpriority="high" />
        </motion.div>
        <div className="absolute inset-0 bg-gradient-to-t from-black/55 via-black/5 to-black/20"></div>
        <div className="relative z-10 mx-auto flex h-full max-w-[1600px] flex-col justify-end px-4 pb-16 sm:px-6 md:px-12 md:pb-24">
          <motion.p initial="hidden" animate="visible" variants={fadeUp} className="label text-smoke/80">Spring Drop 01 · 2026</motion.p>
          <motion.h1 initial="hidden" animate="visible" variants={fadeUp} transition={{ delay: 0.1 }} className="display mt-4 max-w-5xl text-[3.4rem] text-smoke sm:text-7xl md:text-[7.5rem]">
            Move different.<br />Wear wider.
          </motion.h1>
          <motion.div initial="hidden" animate="visible" variants={fadeUp} transition={{ delay: 0.2 }} className="mt-8 flex flex-wrap items-center gap-4">
            <Link to="/shop" data-testid="hero-shop-btn" className="label bg-smoke px-9 py-4 text-ink transition-colors hover:bg-ink hover:text-smoke">
              Shop The Collection
            </Link>
            <Link to="/story" className="label flex items-center gap-2 border border-smoke/40 px-9 py-4 text-smoke transition-colors hover:bg-smoke hover:text-ink">
              The Story 
              <svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="lucide lucide-arrow-up-right">
                <path d="M7 7h10v10"></path>
                <path d="M7 17 17 7"></path>
              </svg>
            </Link>
          </motion.div>
        </div>
      </section>

      {/* 2. Dark Marquee */}
      <Marquee dark={true} />

      {/* 3. Featured Products */}
      <motion.section 
        initial="hidden" whileInView="visible" viewport={{ once: true, amount: 0.1 }}
        className="mx-auto max-w-[1600px] px-4 py-20 sm:px-6 md:px-12 md:py-28" data-testid="featured-section"
      >
        <motion.div variants={fadeUp} className="mb-12 flex flex-col justify-between gap-4 md:flex-row md:items-end">
          <div>
            <p className="label text-ash">The Icons</p>
            <h2 className="display mt-3 text-5xl md:text-7xl">Most Wanted</h2>
          </div>
          <Link to="/shop" className="label link-underline self-start md:self-end">View All →</Link>
        </motion.div>
        <motion.div variants={staggerContainer} className="grid grid-cols-2 gap-x-4 gap-y-12 md:grid-cols-3 lg:grid-cols-4">
          {isLoading ? (
            Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="aspect-[3/4] w-full animate-pulse bg-line" />
            ))
          ) : (
            featured.map((product) => (
              <motion.div variants={fadeUp} key={product.slug}>
                <ProductCard product={product} />
              </motion.div>
            ))
          )}
        </motion.div>
      </motion.section>

      {/* 4. Editorial Section */}
      <section ref={editorialRef} className="grid md:grid-cols-2" data-testid="editorial-section">
        <div className="relative h-[60vh] overflow-hidden bg-bone md:h-[88vh]">
          <motion.div style={{ y: editorialY }} className="absolute inset-0 h-[130%] -top-[15%] w-full">
            <img src="/images/img6.jpeg" alt="Lookbook" className="h-full w-full object-cover" loading="lazy" />
          </motion.div>
        </div>
        <motion.div 
          initial="hidden" whileInView="visible" viewport={{ once: true, amount: 0.3 }} variants={staggerContainer}
          className="flex flex-col justify-center bg-ink px-6 py-16 text-smoke md:px-16"
        >
          <motion.p variants={fadeUp} className="label text-white/50">Lookbook 01</motion.p>
          <motion.h2 variants={fadeUp} className="display mt-5 text-5xl md:text-6xl">Denim,<br />engineered<br />for excess.</motion.h2>
          <motion.p variants={fadeUp} className="mt-7 max-w-md text-base leading-relaxed text-white/70">
            Every PantherClaw pair starts with rigid, honest cotton and ends in a silhouette built to drape, pool and move. No skinny apologies — just volume, done right.
          </motion.p>
          <motion.div variants={fadeUp}>
            <Link to="/shop" data-testid="editorial-cta" className="label mt-9 w-fit block border border-white/40 px-8 py-4 transition-colors hover:bg-smoke hover:text-ink">
              Explore The Range
            </Link>
          </motion.div>
        </motion.div>
      </section>

      {/* 5. Categories Grid */}
      <motion.section 
        initial="hidden" whileInView="visible" viewport={{ once: true, amount: 0.1 }} variants={staggerContainer}
        className="mx-auto max-w-[1600px] px-4 py-20 sm:px-6 md:px-12 md:py-28"
      >
        <div className="grid gap-4 md:grid-cols-2">
          <motion.div variants={fadeUp}>
            <Link to="/shop?category=Women" data-testid="category-women" className="group relative block aspect-[4/5] overflow-hidden bg-bone md:aspect-[3/4]">
              <img src="/images/img2.jpeg" alt="Women" className="img-zoom h-full w-full object-cover" loading="lazy" />
              <div className="absolute inset-0 bg-gradient-to-t from-black/40 to-transparent"></div>
              <div className="absolute bottom-8 left-8 flex items-center gap-3 text-smoke">
                <span className="display text-5xl md:text-6xl">Women</span>
                <svg xmlns="http://www.w3.org/2000/svg" width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="lucide lucide-arrow-up-right transition-transform duration-500 group-hover:translate-x-2 group-hover:-translate-y-2">
                  <path d="M7 7h10v10"></path>
                  <path d="M7 17 17 7"></path>
                </svg>
              </div>
            </Link>
          </motion.div>
          <motion.div variants={fadeUp}>
            <Link to="/shop?category=Men" data-testid="category-men" className="group relative block aspect-[4/5] overflow-hidden bg-bone md:aspect-[3/4]">
              <img src="/images/img1.jpeg" alt="Men" className="img-zoom h-full w-full object-cover" loading="lazy" />
              <div className="absolute inset-0 bg-gradient-to-t from-black/40 to-transparent"></div>
              <div className="absolute bottom-8 left-8 flex items-center gap-3 text-smoke">
                <span className="display text-5xl md:text-6xl">Men</span>
                <svg xmlns="http://www.w3.org/2000/svg" width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="lucide lucide-arrow-up-right transition-transform duration-500 group-hover:translate-x-2 group-hover:-translate-y-2">
                  <path d="M7 7h10v10"></path>
                  <path d="M7 17 17 7"></path>
                </svg>
              </div>
            </Link>
          </motion.div>
        </div>
      </motion.section>

      {/* 6. Quote Section */}
      <section ref={quoteRef} className="relative overflow-hidden h-[70vh]">
        <motion.div style={{ y: quoteY }} className="absolute inset-0 h-[130%] -top-[15%] w-full">
          <img src="/images/img4.jpeg" alt="Editorial" className="h-full w-full object-cover" loading="lazy" />
        </motion.div>
        <div className="absolute inset-0 flex items-center justify-center bg-ink/30 px-6">
          <motion.h2 
            initial={{ opacity: 0, scale: 0.95 }} whileInView={{ opacity: 1, scale: 1 }} transition={{ duration: 0.8 }} viewport={{ once: true }}
            className="display max-w-4xl text-center text-4xl text-smoke md:text-6xl"
          >
            “The right pair of jeans doesn’t fit you. You grow into it.”
          </motion.h2>
        </div>
      </section>

      {/* 7. Light Marquee */}
      <Marquee dark={false} />

    </div>
  );
}
