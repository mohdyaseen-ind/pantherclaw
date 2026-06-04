import React, { useEffect, Suspense, lazy } from "react";
import { BrowserRouter, Routes, Route, useLocation } from "react-router-dom";
import { ReactLenis } from "lenis/react";
import { HelmetProvider } from "react-helmet-async";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { setupRealtimeSubscriptions } from "./lib/api";
import { AuthProvider } from "./context/AuthContext";
import AuthModal from "./components/AuthModal";
import Navbar from "./components/Navbar";
import Footer from "./components/Footer";
import CartDrawer from "./components/CartDrawer";
import LoadingScreen from "./components/LoadingScreen";

// Lazy load route components for code splitting
const Home = lazy(() => import("./pages/Home"));
const Shop = lazy(() => import("./pages/Shop"));
const ProductDetail = lazy(() => import("./pages/ProductDetail"));
const Story = lazy(() => import("./pages/Story"));
const Checkout = lazy(() => import("./pages/Checkout"));
const CheckoutSuccess = lazy(() => import("./pages/CheckoutSuccess"));
// Scroll restoration is natively handled well by React Router 6.4+, or we can add a lightweight hook if needed, but Lenis handles basic scroll reset when properly configured.
// For smooth scrolling, we now use <ReactLenis root>

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: Infinity, // Cache forever, invalidate via Realtime events
      refetchOnWindowFocus: false,
    },
  },
});

// Initialize realtime database subscriptions
setupRealtimeSubscriptions(queryClient);

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <HelmetProvider>
        <AuthProvider>
          <ReactLenis root options={{ duration: 1.1, smoothWheel: true }}>
          <BrowserRouter>
            <Navbar />
            <CartDrawer />
            <main>
              <Suspense fallback={<LoadingScreen />}>
                <Routes>
                  <Route path="/" element={<Home />} />
                  <Route path="/shop" element={<Shop />} />
                  <Route path="/product/:slug" element={<ProductDetail />} />
                  <Route path="/story" element={<Story />} />
                  <Route path="/checkout" element={<Checkout />} />
                  <Route path="/checkout/success" element={<CheckoutSuccess />} />
                </Routes>
              </Suspense>
            </main>
            <Footer />
          </BrowserRouter>
        </ReactLenis>
      </AuthProvider>
    </HelmetProvider>
    </QueryClientProvider>
  );
}
