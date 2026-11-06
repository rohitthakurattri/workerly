# One image, three apps. APP_TARGET (customer | worker | admin) picks which Nitro server runs;
# runtime settings come from NUXT_PUBLIC_* environment variables (API base, tiles, asset origins).
FROM node:24-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts
COPY . .
RUN npx nuxt prepare && npm run build:all

FROM node:24-slim
WORKDIR /app
ENV NODE_ENV=production PORT=3000 HOST=0.0.0.0
COPY --from=build /app/.output ./.output
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD node -e "fetch('http://localhost:'+process.env.PORT+'/manifest.webmanifest').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["sh", "-c", "case \"$APP_TARGET\" in customer|worker|admin) exec node .output/$APP_TARGET/server/index.mjs;; *) echo 'APP_TARGET must be customer, worker or admin' >&2; exit 1;; esac"]
