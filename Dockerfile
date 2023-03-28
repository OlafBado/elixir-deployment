ARG MIX_ENV="prod"
# build stage
FROM hexpm/elixir:1.14.3-erlang-23.2.6-alpine-3.15.0 AS build 
# install build dependencies
RUN apk add --no-cache build-base git python3 curl
# sets work dir
WORKDIR /app
# install hex + rebar
RUN mix local.hex --force
RUN mix local.rebar --force

# arg is passed to from outside to the docker
# we redeclare it because after FORM statement it is lost
# and we can use its default value by redeclaring it
ARG MIX_ENV
# env will exist during image build process
ENV MIX_ENV="${MIX_ENV}"
# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
# copy compile configuration files
RUN mkdir config
COPY config/config.exs config/$MIX_ENV.exs config/
# compile dependencies
RUN mix deps.compile
# copy assets
COPY priv priv
COPY assets assets
# Compile assets
RUN mix assets.deploy
# compile project
COPY lib lib 
RUN mix compile
# copy runtime configuration file
COPY config/runtime.exs config/ 
# assemble release
RUN mix release

#---------- app stage --------------
FROM alpine:3.14.2 AS app

ARG MIX_ENV
# install runtime dependencies
RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR "/home/elixir/app"
# Create  unprivileged user to run the release
RUN \
    addgroup \
    -g 1000 \
    -S "elixir" \
    && adduser \
    -s /bin/sh \
    -u 1000 \
    -G "elixir" \
    -h "/home/elixir" \ 
    -D "elixir" \
    && su "elixir"
# run as user
USER "elixir"

# copy release executables
COPY --from=build --chown="elixir":"elixir" /app/_build/"${MIX_ENV}"/rel/saturn ./

ENTRYPOINT ["bin/saturn"]

CMD ["start"]

