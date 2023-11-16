# Silo V2

Monorepo for Silo protocol. v2

## Development setup

see:

- https://yarnpkg.com/getting-started/install
- https://classic.yarnpkg.com/lang/en/docs/workspaces/

```shell
# from root dir
git clone <repo>
git hf init

nvm install 18
nvm use 18

# this is for ode 18, for other versions please check https://yarnpkg.com/getting-started/install
corepack enable
corepack prepare yarn@stable --activate

npm i -g yarn
yarn install

git config core.hooksPath .githooks/
```

### Foundry setup for monorepo

```
git submodule add --name foundry https://github.com/foundry-rs/forge-std gitmodules/forge-std
git submodule add --name silo-foundry-utils https://github.com/silo-finance/silo-foundry-utils gitmodules/silo-foundry-utils
forge install OpenZeppelin/openzeppelin-contracts --no-commit 
forge install OpenZeppelin/openzeppelin-contracts-upgradeable --no-commit
git submodule add --name gitmodules/uniswap/v3-periphery https://github.com/Uniswap/v3-periphery gitmodules/uniswap/v3-periphery 
git submodule add --name gitmodules/chainlink https://github.com/smartcontractkit/chainlink gitmodules/chainlink 
git submodule add --name lz_gauges https://github.com/LayerZero-Labs/lz_gauges gitmodules/lz_gauges
git submodule add --name layer-zero-examples https://github.com/LayerZero-Labs/solidity-examples gitmodules/layer-zero-examples
git submodule add --name chainlink-ccip https://github.com/smartcontractkit/ccip gitmodules/chainlink-ccip
git submodule update --init --recursive
git submodule
```

create `.remappings.txt` in main directory

```
forge-std/=gitmodules/forge-std/src/
```

this will make forge visible for imports eg: `import "forge-std/Test.sol"`.

### Build Silo Foundry Utils
```bash
cd gitmodules/silo-foundry-utils
cargo build --release
cp target/release/silo-foundry-utils ../../silo-foundry-utils
```

More about silo foundry utils [here](https://github.com/silo-finance/silo-foundry-utils).

### Remove submodule

example:

```shell
# Remove the submodule entry from .git/config
git submodule deinit -f gitmodules/silo-foundry-utils

# Remove the submodule directory from the superproject's .git/modules directory
rm -rf .git/modules/gitmodules/silo-foundry-utils

# Remove the entry in .gitmodules and remove the submodule directory located at path/to/submodule
rm -rf gitmodules/silo-foundry-utils
```

### Update submodule
```shell
git submodule update --remote gitmodules/<submodule>
```

If you want to update to specific commit:
1. cd `gitmodules/<module>`
2. `git checkout <commit>`
3. commit changes (optinally update `branch` section in `.gitmodules`, however this make no difference)

## Adding new working space

- create new workflow in `.github/workflows`
- create new directory `mkdir new-dir` with content
- create new profile in `.foundry.toml`
- add new workspace in `package.json` `workspaces` section
- run `yarn reinstall`

## Cloning external code

- In `external/` create subdirectory for cloned code eg `uniswap-v3-core/`
- clone git repo into that directory

**NOTICE**: do not run `yarn install` directly from workspace directory. It will create separate `yarn.lock` and it will
act like separate repo, not part of monorepo. It will cause issues when trying to access other workspaces eg as
dependency.
- you need to remove `./git` directories in order to commit cloned code
- update `external/package.json#workspaces` with this new `uniswap-v3-core`
- update `external/uniswap-v3-core/package.json#name` to match dir name, in our example `uniswap-v3-core`

Run `yarn install`, enter your new cloned workspace, and you should be able to execute commands for this new workspace.

example of running scripts for workspace:

```shell
yarn workspace <workspaceName> <commandName> ...
```

## Coverage Report


```shell
brew install lcov

rm lcov.info
mkdir coverage
FOUNDRY_PROFILE=core forge coverage --report summary --report lcov --ffi | grep -i 'silo-core/contracts/' > coverage/silo-core.txt
genhtml -o coverage/silo-core/ lcov.info

rm lcov.info
FOUNDRY_PROFILE=oracles forge coverage --report summary --report lcov | grep -i 'silo-oracles/contracts/' > coverage/silo-oracles.txt
genhtml -o coverage/silo-oracles/ lcov.info
```
