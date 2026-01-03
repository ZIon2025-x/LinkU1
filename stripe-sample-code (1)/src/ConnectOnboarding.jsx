import React, { useState } from "react";
import { useAccount } from "./AccountProvider";
import AccountStatus from "./AccountStatus";

const ConnectOnboarding = () => {
  const [email, setEmail] = useState("");
  const { accountId, setAccountId } = useAccount();

  const handleCreateAccount = async (e) => {
    e.preventDefault();

    try {
      const response = await fetch("/api/create-connect-account", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ email }),
      });

      if (!response.ok) {
        throw new Error("Failed to create account");
      }

      const data = await response.json();

      // Update the account ID in the provider
      setAccountId(data.accountId);
    } catch (error) {
      console.error("Error creating account:", error);
    }
  };

  const handleStartOnboarding = async () => {
    try {
      const response = await fetch("/api/create-account-link", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ accountId }),
      });

      if (!response.ok) {
        throw new Error("Failed to create account link");
      }

      const data = await response.json();
      window.location.href = data.url;
    } catch (error) {
      console.error("Error creating account link:", error);
    }
  };

  return (
    <div className="container">
      {!accountId ? (
        <form onSubmit={handleCreateAccount}>
          <div className="form-group">
            <label htmlFor="email">Email for Connected account:</label>
            <input
              type="email"
              id="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>
          <button className="button" type="submit">
            Create Connect Account
          </button>
        </form>
      ) : (
        <AccountStatus onStartOnboarding={handleStartOnboarding} />
      )}
    </div>
  );
};

export default ConnectOnboarding;