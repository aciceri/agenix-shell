{
  inputs,
  withSystem,
  ...
}: {
  flake.githubActions = inputs.nix-github-actions.lib.mkGithubMatrix (withSystem "x86_64-linux" (ctx: {inherit (ctx.config) checks;}));
}
