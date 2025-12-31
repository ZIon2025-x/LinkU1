import React from "react";
import Products from "./Products";
import { useAccount } from "./AccountProvider";

const Storefront = () => {
  const { accountId } = useAccount();

  return (
    <div className="App">
      <div className="container">
        <div className="logo">
          {accountId === "platform"
            ? "Platform Products"
            : `Store ${accountId}`}
        </div>
        <Products />
      </div>
    </div>
  );
};

export default Storefront;