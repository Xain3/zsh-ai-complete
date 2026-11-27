# Versioning and releases

The fork uses [Semantic Versioning 2.0.0](https://semver.org/): `MAJOR.MINOR.PATCH`.
The version in `package.json` is the source of truth. A released Git tag is
`v` followed by that exact version, for example `v1.1.0`. Never move or reuse a
published version or tag. This process creates GitHub releases; it does not
publish a package to npm.

The public interface includes the documented Zsh commands and shortcuts,
provider and settings JSON formats, installation instructions, and required
runtime tools. Choose the increment based on the effect on users:

- **Patch:** backward-compatible bug or security fixes.
- **Minor:** backward-compatible functionality, such as a new optional setting.
- **Major:** incompatible behavior, configuration, supported environments, or
  minimum dependency changes for an already released version.

The inherited `package.json` version is `1.0.0`; the fork currently has no
release tags. The changelog retains the original project's history separately.
The included minor changeset records features already merged into this fork,
so the first version-preparation step proposes `1.1.0`. No fork release exists
until a maintainer creates and pushes its tag.

## Record a change

For each user-facing change, include a changeset in its pull request:
This requires Node.js and Corepack; install Corepack separately if your Node.js
distribution does not include it.

```sh
corepack yarn install --frozen-lockfile
corepack yarn changeset
```

Select `zsh-ai-complete`, choose the appropriate bump, and describe the change
in user-facing language. Commit the new `.changeset/*.md` file with the change.
Documentation-only or internal changes that do not affect users need no
changeset. When several changesets are pending, Changesets combines them and
uses the highest required increment.

## Prepare a stable release

1. Start from an up-to-date `main` and create a release branch.
2. Run `corepack yarn install --frozen-lockfile` and
   `corepack yarn version-packages`. Changesets consumes pending changesets,
   updates `package.json`, and adds their notes to `CHANGELOG.md`.
3. Review the version and changelog, run `corepack yarn test:release`, commit
   the changes, and open a pull request into `main`. Merge it after review.
4. Update the local `main`, check that the version and intended commit are
   correct, then create and push the matching annotated tag:

   ```sh
   git switch main
   git pull --ff-only
   git tag -a v1.1.0 -m "Release v1.1.0"
   git push origin v1.1.0
   ```

   Substitute the prepared version for `1.1.0`. Pushing the tag triggers the
   GitHub release workflow. It checks that the tag is valid SemVer, exactly
   matches `package.json`, and points to a commit reachable from `main`; it
   then creates a GitHub release with generated notes. Existing releases and
   tags are not overwritten. The workflow needs Actions to have write access
   to repository contents. If it fails, inspect the workflow before retrying.

## Prereleases

Use Changesets' prerelease mode on a dedicated release branch:

```sh
corepack yarn changeset pre enter beta
corepack yarn version-packages
```

Review and merge the resulting prerelease version and changelog, then push the
matching `v...-beta.N` tag using the same steps above. The release workflow
marks any SemVer prerelease as a GitHub prerelease. Subsequent prereleases
require new changesets and another version-preparation step. To leave the
prerelease cycle, run `corepack yarn changeset pre exit` and
`corepack yarn version-packages`, review the resulting stable version in a
pull request, and then tag it after merging. Do not leave prerelease mode active
on `main` unintentionally.
