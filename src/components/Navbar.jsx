import React, { useEffect, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { ShoppingBag, Search, Menu, X, User } from "lucide-react";
import { useCartStore } from "../store/cartStore";
import { useAuth } from "../context/AuthContext";
import AuthModal from "./AuthModal";

const links = [
  { label: "Shop All", to: "/shop" },
  { label: "Women", to: "/shop?category=Women" },
  { label: "Men", to: "/shop?category=Men" },
  { label: "Story", to: "/story" },
];

export default function Navbar() {
  const { count, setOpen } = useCartStore();
  const { user, signOut } = useAuth();
  const [authModalOpen, setAuthModalOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const [menu, setMenu] = useState(false);
  const location = useLocation();

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 40);
    onScroll();
    window.addEventListener("scroll", onScroll);
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => setMenu(false), [location]);

  useEffect(() => {
    if (menu) {
      document.body.style.overflow = "hidden";
    } else {
      document.body.style.overflow = "";
    }
    return () => {
      document.body.style.overflow = "";
    };
  }, [menu]);

  return (
    <header
      data-testid="main-navigation"
      className={`fixed inset-x-0 top-0 z-50 transition-all duration-500 ${
        scrolled ? "bg-smoke/80 backdrop-blur-xl border-b border-black/5" : "bg-transparent"
      }`}
    >
      <div className="mx-auto flex max-w-[1600px] items-center justify-between px-4 py-4 sm:px-6 md:px-12">
        {/* Left nav */}
        <nav className="hidden flex-1 items-center gap-8 md:flex">
          {links.map((l) => (
            <Link
              key={l.label}
              to={l.to}
              data-testid={`nav-${l.label.toLowerCase().replace(/\\s/g, "-")}`}
              className="label link-underline text-[0.66rem] text-white"
            >
              {l.label}
            </Link>
          ))}
        </nav>

        <button
          data-testid="mobile-menu-toggle"
          onClick={() => setMenu((m) => !m)}
          className="flex-1 md:hidden"
          aria-label="Menu"
          aria-expanded={menu}
        >
          {menu ? <X size={22} aria-hidden="true" /> : <Menu size={22} aria-hidden="true" />}
        </button>

        {/* Logo */}
        <Link to="/" data-testid="brand-logo" className="flex-1 text-center">
          <span className="display text-2xl tracking-tight md:text-[1.7rem] text-white">PANTHERCLAW</span>
        </Link>

        {/* Right */}
        <div className="flex flex-1 items-center justify-end gap-5">
          <button data-testid="search-btn" aria-label="Search" className="hidden sm:block text-white">
            <Search size={19} strokeWidth={1.6} aria-hidden="true" />
          </button>
          
          {user ? (
            <button onClick={signOut} aria-label="Sign Out" className="hidden sm:block hover:opacity-50 text-white">
              <User size={19} strokeWidth={1.6} aria-hidden="true" className="text-blue-500" />
            </button>
          ) : (
            <button onClick={() => setAuthModalOpen(true)} aria-label="Sign In" className="hidden sm:block text-white">
              <User size={19} strokeWidth={1.6} aria-hidden="true" />
            </button>
          )}

          <button
            data-testid="cart-toggle"
            onClick={() => setOpen(true)}
            className="relative text-white"
            aria-label="Cart"
          >
            <ShoppingBag size={19} strokeWidth={1.6} aria-hidden="true" />
            {count > 0 && (
              <span
                data-testid="cart-count"
                className="absolute -right-2 -top-2 flex h-4 w-4 items-center justify-center rounded-full bg-ink text-[0.55rem] font-bold text-smoke"
              >
                {count}
              </span>
            )}
          </button>
        </div>
      </div>

      {/* Mobile menu */}
      {menu && (
        <div className="border-t border-black/5 bg-smoke px-6 py-6 md:hidden">
          {links.map((l) => (
            <Link
              key={l.label}
              to={l.to}
              className="block py-3 font-serif text-3xl"
            >
              {l.label}
            </Link>
          ))}
          {user ? (
            <button onClick={signOut} className="block py-3 font-serif text-3xl text-left w-full text-blue-500">
              Sign Out
            </button>
          ) : (
            <button onClick={() => { setAuthModalOpen(true); setMenu(false); }} className="block py-3 font-serif text-3xl text-left w-full">
              Sign In
            </button>
          )}
        </div>
      )}

      <AuthModal isOpen={authModalOpen} onClose={() => setAuthModalOpen(false)} />
    </header>
  );
}
