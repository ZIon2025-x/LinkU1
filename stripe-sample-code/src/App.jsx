import React, { useState, useEffect } from "react";
import { loadStripe } from "@stripe/stripe-js";
import { Elements } from "@stripe/react-stripe-js";
import {
  BrowserRouter as Router,
  Routes,
  Route
} from 'react-router-dom';

import CheckoutForm from "./CheckoutForm";
import CompletePage from "./CompletePage";
import "./App.css";

// Make sure to call loadStripe outside of a component’s render to avoid
// recreating the Stripe object on every render.
// This is your test publishable API key.
const stripePromise = loadStripe("pk_test_51SePW98JTHo8ClgaUWRjX9HHabiw09tJQLJlQdJXYCNMVDFr9B9ZeWNwkH9D8NRxreIew4AfQ7hByO6l37KdEkAa00yqY1lz0P");

export default function App() {
  const [clientSecret, setClientSecret] = useState("");

  useEffect(() => {
    // Create PaymentIntent as soon as the page loads
    fetch("/create-payment-intent", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ items: [{ id: "xl-tshirt", amount: 1000 }] }),
    })
      .then((res) => res.json())
      .then((data) => setClientSecret(data.clientSecret));
  }, []);

  const appearance = {
    theme: 'stripe',
  };
  // Enable the skeleton loader UI for optimal loading.
  const loader = 'auto';

  return (
    <Router>
      <div className="App">
        {clientSecret && (
          <Elements options={{clientSecret, appearance, loader}} stripe={stripePromise}>
            <Routes>
              <Route path="/checkout" element={<CheckoutForm />} />
              <Route path="/complete" element={<CompletePage />} />
            </Routes>
          </Elements>
        )}
      </div>
    </Router>
  );
}