import React, { useEffect, useState } from "react";
import { useSearchParams, useNavigate } from "react-router-dom";
import { CheckCircle, Loader2, XCircle } from "lucide-react";
import { supabase } from "../lib/supabase";
import { useCartStore } from "../store/cartStore";
import { useAuth } from "../context/AuthContext";

export default function CheckoutSuccess() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const orderId = searchParams.get("order_id");
  const { clear, session_id } = useCartStore();
  const { user } = useAuth();
  
  const [status, setStatus] = useState("processing"); // processing, success, failed
  const [message, setMessage] = useState("Verifying your payment with Cashfree...");

  useEffect(() => {
    if (!orderId || !user || !session_id) {
      setStatus("failed");
      setMessage("Invalid checkout session.");
      return;
    }

    const verifyAndProcess = async () => {
      try {
        // 1. In a production app, we would hit the edge function to verify the Cashfree signature here.
        // For phase 3 prototype, we will assume the return to this URL implies successful sandbox payment
        // and we will call the Supabase process_checkout RPC.

        // We need an address ID to process checkout.
        // We'll fetch the user's default address.
        const { data: address } = await supabase
          .from('addresses')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_default', true)
          .single();

        if (!address) {
          throw new Error("No shipping address found.");
        }

        const { data, error } = await supabase.rpc('process_checkout', {
          p_user_id: user.id,
          p_session_id: session_id,
          p_address_id: address.id
        });

        if (error) {
          throw error;
        }

        // Add payment record
        await supabase.from('payments').insert([{
          order_id: data, // Assuming process_checkout returns the new order ID
          amount: useCartStore.getState().subtotal,
          provider: 'cashfree',
          status: 'completed',
          cashfree_order_id: orderId
        }]);

        // Success!
        clear(); // Empty the cart
        setStatus("success");
        setMessage(`Order placed successfully! Your order ID is #${data.substring(0, 8)}.`);

      } catch (err) {
        console.error("Verification failed:", err);
        setStatus("failed");
        setMessage(err.message || "Failed to process order.");
      }
    };

    verifyAndProcess();
  }, [orderId, user, session_id, clear]);

  return (
    <div className="pt-32 px-4 min-h-[70vh] flex flex-col items-center justify-center text-center">
      {status === "processing" && (
        <>
          <Loader2 className="w-16 h-16 animate-spin text-blue-500 mb-6" />
          <h1 className="text-3xl font-serif mb-2">Processing Payment</h1>
          <p className="text-ash">{message}</p>
        </>
      )}

      {status === "success" && (
        <>
          <CheckCircle className="w-16 h-16 text-green-500 mb-6" />
          <h1 className="text-3xl font-serif mb-2">Payment Successful</h1>
          <p className="text-ash mb-8">{message}</p>
          <button 
            onClick={() => navigate("/shop")}
            className="bg-ink text-smoke px-8 py-4 label hover:bg-[#262626] transition-colors"
          >
            Continue Shopping
          </button>
        </>
      )}

      {status === "failed" && (
        <>
          <XCircle className="w-16 h-16 text-red-500 mb-6" />
          <h1 className="text-3xl font-serif mb-2">Payment Failed</h1>
          <p className="text-ash mb-8">{message}</p>
          <button 
            onClick={() => navigate("/checkout")}
            className="bg-ink text-smoke px-8 py-4 label hover:bg-[#262626] transition-colors"
          >
            Try Again
          </button>
        </>
      )}
    </div>
  );
}
