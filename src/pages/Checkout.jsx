import React, { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Loader2 } from "lucide-react";
import { useCartStore } from "../store/cartStore";
import { useAuth } from "../context/AuthContext";
import { formatPrice } from "../lib/api";
import { supabase } from "../lib/supabase";
import { load } from "@cashfreepayments/cashfree-js";

export default function Checkout() {
  const { items, subtotal, clear, session_id } = useCartStore();
  const { user } = useAuth();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [cashfree, setCashfree] = useState(null);

  // Hardcoded address for prototype. Phase 4 will introduce full address management.
  const address = {
    address_line_1: "123 Main St",
    city: "Bangalore",
    state: "Karnataka",
    postal_code: "560001"
  };

  useEffect(() => {
    // Initialize Cashfree SDK
    load({ mode: "sandbox" }).then((cf) => {
      setCashfree(cf);
    });
  }, []);

  if (!user) {
    return (
      <div className="pt-32 text-center min-h-[60vh]">
        <h2 className="text-2xl font-serif">Please log in to checkout</h2>
        <button onClick={() => navigate("/")} className="mt-4 underline text-ash">Return Home</button>
      </div>
    );
  }

  if (items.length === 0) {
    return (
      <div className="pt-32 text-center min-h-[60vh]">
        <h2 className="text-2xl font-serif">Your cart is empty</h2>
        <button onClick={() => navigate("/shop")} className="mt-4 underline text-ash">Return to Shop</button>
      </div>
    );
  }

  const handlePayment = async () => {
    setLoading(true);
    try {
      // 1. Ensure we have an address in DB for the checkout process
      let { data: addressData } = await supabase
        .from('addresses')
        .select('*')
        .eq('user_id', user.id)
        .eq('is_default', true)
        .single();

      if (!addressData) {
        const { data: newAddress, error: addressError } = await supabase
          .from('addresses')
          .insert([{
            user_id: user.id,
            label: 'Home',
            address_line_1: address.address_line_1,
            city: address.city,
            state: address.state,
            postal_code: address.postal_code,
            is_default: true
          }])
          .select()
          .single();

        if (addressError) throw addressError;
        addressData = newAddress;
      }

      // 2. Call our Supabase Edge Function to generate the Cashfree Session
      const { data: edgeData, error: edgeError } = await supabase.functions.invoke('cashfree-checkout', {
        body: {
          action: 'create-order',
          amount: subtotal,
          customerId: user.id,
          customerPhone: user.phone_number || "9999999999", // Fallback to 9999999999 if phone missing
          customerEmail: user.email
        }
      });

      if (edgeError) throw edgeError;
      if (!edgeData?.payment_session_id) throw new Error("Failed to generate payment session");

      // 3. Open Cashfree Checkout Modal
      let checkoutOptions = {
        paymentSessionId: edgeData.payment_session_id,
        returnUrl: `${window.location.origin}/checkout?order_id={order_id}` // Cashfree replaces {order_id} automatically
      };

      // Since we want to use the modal overlay rather than redirecting away if possible
      // But standard Cashfree SDK flow with redirect:
      await cashfree.checkout(checkoutOptions);
      
      // Note: The execution stops here as Cashfree takes over or redirects.
      // The returnUrl handler (in a useEffect below) handles the verification.

    } catch (err) {
      console.error(err);
      alert("Checkout failed: " + err.message);
      setLoading(false);
    }
  };

  return (
    <div className="pt-32 px-4 sm:px-6 md:px-12 max-w-[1200px] mx-auto min-h-screen">
      <h1 className="text-3xl font-serif mb-8">Checkout</h1>
      
      <div className="flex flex-col lg:flex-row gap-12">
        {/* Left Col - Address (Mocked for now) */}
        <div className="flex-1 space-y-8">
          <section className="bg-smoke p-6 border border-line">
            <h2 className="text-xl mb-4 border-b border-line pb-2">Shipping Address</h2>
            <div className="text-ash text-sm space-y-1">
              <p className="text-ink font-medium">{user.user_metadata?.full_name || "User"}</p>
              <p>{address.address_line_1}</p>
              <p>{address.city}, {address.state} {address.postal_code}</p>
            </div>
          </section>
        </div>

        {/* Right Col - Order Summary */}
        <div className="w-full lg:w-[400px] flex-shrink-0">
          <div className="bg-smoke p-6 border border-line sticky top-32">
            <h2 className="text-xl mb-4 border-b border-line pb-2">Order Summary</h2>
            <ul className="space-y-4 mb-6">
              {items.map(item => (
                <li key={item.key} className="flex justify-between text-sm">
                  <div className="flex items-center gap-3">
                    <img src={item.image} alt={item.name} className="w-12 h-16 object-cover bg-bone" />
                    <div>
                      <p className="font-medium text-ink">{item.name}</p>
                      <p className="text-ash text-xs">Qty: {item.qty} | Size: {item.size}</p>
                    </div>
                  </div>
                  <span className="font-medium">{formatPrice(item.price * item.qty)}</span>
                </li>
              ))}
            </ul>
            
            <div className="border-t border-line pt-4 flex justify-between font-semibold text-lg">
              <span>Total</span>
              <span>{formatPrice(subtotal)}</span>
            </div>

            <button
              onClick={handlePayment}
              disabled={loading || !cashfree}
              className="w-full mt-6 bg-blue-600 hover:bg-blue-700 text-white py-4 font-medium transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
            >
              {loading ? <Loader2 className="w-5 h-5 animate-spin" /> : "Pay via Cashfree"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
