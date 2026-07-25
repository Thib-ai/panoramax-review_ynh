# Panoramax Review for YunoHost

Review street-level imagery from Panoramax. Import pictures, flag errors, track issues.

## Installation

```bash
sudo yunohost app install https://github.com/thibaultmol/panoramax-review_ynh
```

## Documentation

- YunoHost documentation: https://yunohost.org/apps
- Panoramax: https://panoramax.mapcomplete.org

## Development

```bash
# Build the app
cd panoramax-review
npm ci
npm run build

# Test with YunoHost
sudo yunohost app install /path/to/panoramax-review_ynh -a "domain=your.domain.tld&path=/review"
```
