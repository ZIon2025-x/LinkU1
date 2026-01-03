import React, { useState, useEffect } from "react";
import { useAccount } from "./AccountProvider";
import useAccountStatus from "./useAccountStatus";
import { Link } from "react-router-dom";

const Product = ({ name, price, priceId, period, image }) => {
  const { accountId } = useAccount();

  return (
    <div className="product round-border">
      <div className="product-info">
        <img src={image} alt={name} />
        <div className="description">
          <h3>{name}</h3>
          <h5>{price} {period && `/ ${period}`}</h5>
        </div>
      </div>

      <form action="/api/create-checkout-session" method="POST">
        <input type="hidden" name="priceId" value={priceId} />
        <input type="hidden" name="accountId" value={accountId} />
        <button className="button" type="submit">
          Checkout
        </button>
      </form>
    </div>
  );
};

const Products = () => {
  const { accountId } = useAccount();
  const { needsOnboarding } = useAccountStatus();
  const [products, setProducts] = useState([]);

  const fetchProducts = async () => {
    if (!accountId) return;
    if (needsOnboarding) return;
    const response = await fetch(`/api/products/${accountId}`);
    const data = await response.json();
    setProducts(data);
  };

  useEffect(() => {
    const intervalId = setInterval(fetchProducts, 5000);
    fetchProducts();

    return () => clearInterval(intervalId);
  }, [accountId, needsOnboarding]);

  return (
    <div>
      {products.map((product) => (
        <Product key={product.name} {...product} />
      ))}
    </div>
  );
};

export default Products;

