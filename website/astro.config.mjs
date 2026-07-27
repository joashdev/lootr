import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://lootr-bhl.pages.dev',
  output: 'static',
  build: {
    assets: 'assets',
  },
});
