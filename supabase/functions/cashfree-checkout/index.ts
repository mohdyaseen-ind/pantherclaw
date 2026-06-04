import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Use provided test keys as fallback for prototype if env vars aren't set
const CASHFREE_APP_ID = Deno.env.get("CASHFREE_APP_ID") || "";
const CASHFREE_SECRET_KEY = Deno.env.get("CASHFREE_SECRET_KEY") || "";

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { action, amount, customerId, customerPhone, customerEmail, orderId } = await req.json();

    if (action === 'create-order') {
      // 1. Generate a unique order ID for Cashfree
      const cashfreeOrderId = `order_${Date.now()}_${customerId.substring(0, 5)}`;
      
      // 2. Call Cashfree API to create the order session
      // For INR, amount must be in rupees (amount from frontend is likely in paise based on V2 schema, so divide by 100)
      const orderAmount = (amount / 100).toFixed(2);

      const response = await fetch("https://sandbox.cashfree.com/pg/orders", {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-client-id': CASHFREE_APP_ID,
          'x-client-secret': CASHFREE_SECRET_KEY,
          'x-api-version': '2023-08-01',
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          order_id: cashfreeOrderId,
          order_amount: orderAmount,
          order_currency: "INR",
          customer_details: {
            customer_id: customerId,
            customer_phone: customerPhone || "9999999999",
            customer_email: customerEmail || "test@example.com"
          },
          order_meta: {
            return_url: `${req.headers.get("origin")}/checkout/success?order_id={order_id}`
          }
        })
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(`Cashfree error: ${JSON.stringify(data)}`);
      }

      return new Response(
        JSON.stringify({ payment_session_id: data.payment_session_id, order_id: cashfreeOrderId }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      );
    }
    
    // Add verify-payment action here when building Phase 4 (Webhook Verification)
    
    throw new Error(`Unknown action: ${action}`);

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    );
  }
});
