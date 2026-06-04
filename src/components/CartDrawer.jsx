import React, { useEffect, useRef } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { useNavigate } from "react-router-dom";
import { X, Minus, Plus, ShoppingBag } from "lucide-react";
import { useCartStore } from "../store/cartStore";
import { formatPrice } from "../lib/api";

export default function CartDrawer() {
  const { open, setOpen, items, removeItem, changeQty, subtotal } = useCartStore();
  const navigate = useNavigate();
  const dialogRef = useRef(null);

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;

    if (open && !dialog.open) {
      dialog.showModal();
    } else if (!open && dialog.open) {
      dialog.close();
    }
  }, [open]);

  // Handle native escape key
  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;
    
    const onCancel = (e) => {
      e.preventDefault();
      setOpen(false);
    };
    dialog.addEventListener("cancel", onCancel);
    return () => dialog.removeEventListener("cancel", onCancel);
  }, [setOpen]);

  return (
    <dialog
      ref={dialogRef}
      className="m-0 h-[100svh] max-h-none w-full max-w-md translate-x-full border-l border-line bg-smoke p-0 text-ink backdrop:bg-ink/40 backdrop:backdrop-blur-sm transition-transform duration-500 ease-[cubic-bezier(0.16,1,0.3,1)] open:translate-x-0 fixed right-0 left-auto"
      onClick={(e) => {
        if (e.target === dialogRef.current) setOpen(false);
      }}
    >
      <div className="flex h-full w-full flex-col">
            <div className="flex items-center justify-between border-b border-line px-6 py-5">
              <span className="label">Your Bag ({items.length})</span>
              <button data-testid="cart-close" onClick={() => setOpen(false)} aria-label="Close">
                <X size={20} />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto px-6">
              {items.length === 0 ? (
                <div className="flex h-full flex-col items-center justify-center text-center">
                  <p className="font-serif text-3xl">Your bag is empty</p>
                  <p className="mt-2 text-sm text-ash">Time to find your pair.</p>
                  <button
                    onClick={() => setOpen(false)}
                    className="label mt-6 border border-ink px-7 py-3 transition-colors hover:bg-ink hover:text-smoke"
                  >
                    Continue Shopping
                  </button>
                </div>
              ) : (
                <ul className="divide-y divide-line">
                  {items.map((it) => (
                    <li key={it.key} className="flex gap-4 py-5" data-testid={`cart-item-${it.key}`}>
                      <div className="h-28 w-20 flex-shrink-0 overflow-hidden bg-bone">
                        <img src={it.image} alt={it.name} className="h-full w-full object-cover" />
                      </div>
                      <div className="flex flex-1 flex-col">
                        <div className="flex justify-between">
                          <div>
                            <p className="text-sm font-semibold">{it.name}</p>
                            <p className="text-xs text-ash">{it.subtitle} · Size {it.size}</p>
                          </div>
                          <button
                            onClick={() => removeItem(it.key)}
                            className="text-ash hover:text-ink"
                            data-testid={`cart-remove-${it.key}`}
                          >
                            <X size={16} />
                          </button>
                        </div>
                        <div className="mt-auto flex items-center justify-between">
                          <div className="flex items-center border border-line">
                            <button
                              onClick={() => changeQty(it.key, -1)}
                              className="px-2.5 py-1.5 hover:bg-line"
                              data-testid={`cart-dec-${it.key}`}
                            >
                              <Minus size={13} />
                            </button>
                            <span className="px-3 text-sm">{it.qty}</span>
                            <button
                              onClick={() => changeQty(it.key, 1)}
                              className="px-2.5 py-1.5 hover:bg-line"
                              data-testid={`cart-inc-${it.key}`}
                            >
                              <Plus size={13} />
                            </button>
                          </div>
                          <span className="text-sm font-medium">{formatPrice(it.price * it.qty)}</span>
                        </div>
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </div>

            {items.length > 0 && (
              <div className="border-t border-line px-6 py-6">
                <div className="flex justify-between">
                  <span className="label">Subtotal</span>
                  <span data-testid="cart-subtotal" className="text-base font-semibold">
                    {formatPrice(subtotal)}
                  </span>
                </div>
                <p className="mt-1 text-xs text-ash">Shipping & taxes calculated at checkout.</p>
                <button
                  data-testid="checkout-btn"
                  className="label mt-5 w-full bg-ink py-4 text-smoke transition-colors hover:bg-[#262626]"
                  onClick={() => {
                    setOpen(false);
                    navigate("/checkout");
                  }}
                >
                  Checkout · {formatPrice(subtotal)}
                </button>
                <p className="mt-3 text-center text-[0.62rem] uppercase tracking-[0.2em] text-ash">
                  Secure payments · Cashfree
                </p>
              </div>
            )}
      </div>
    </dialog>
  );
}
