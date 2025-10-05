# Access Control

## Roles

### ADMIN_ROLE
- Full system control
- Can grant/revoke roles
- Emergency functions

### OPERATOR_ROLE
- Marketplace operations
- Can pause/unpause specific features
- Fee management

### EMERGENCY_ROLE
- Emergency pause only
- Limited scope for security

## Permissions Matrix

| Function | Admin | Operator | Emergency | Public |
|----------|-------|----------|-----------|--------|
| Create Listing | ❌ | ❌ | ❌ | ✅ |
| Cancel Listing | ❌ | ❌ | ❌ | ✅ (owner) |
| Update Fees | ✅ | ✅ | ❌ | ❌ |
| Pause System | ✅ | ❌ | ✅ | ❌ |
| Withdraw Funds | ✅ | ❌ | ❌ | ❌ |

[To be expanded]
