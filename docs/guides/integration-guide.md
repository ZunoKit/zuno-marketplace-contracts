# Integration Guide

## For Frontend Developers

### Installing Dependencies

```bash
npm install ethers@^6.0.0
```

### Contract ABIs

ABIs are available in `/abis` directory after running:
```bash
make update-abi
```

### Basic Integration Example

```javascript
import { ethers } from 'ethers';
import ERC721Exchange from './abis/ERC721NFTExchange.json';

const provider = new ethers.BrowserProvider(window.ethereum);
const signer = await provider.getSigner();

const exchange = new ethers.Contract(
  EXCHANGE_ADDRESS,
  ERC721Exchange.abi,
  signer
);

// Create listing
const tx = await exchange.createListing(
  nftAddress,
  tokenId,
  ethers.parseEther("1.0"),
  86400 // 1 day
);
await tx.wait();
```

## For Smart Contract Integration

[To be documented]
