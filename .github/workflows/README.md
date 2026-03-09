# Claude PR Review GitHub Action

This workflow automatically reviews pull requests using Claude AI via Attentive's centralized reusable workflow.

## Features

- 🤖 **Automatic reviews** when PRs are opened, updated, or review is requested
- 📝 **Comprehensive analysis** including code quality, bugs, security concerns
- 💬 **Posted as PR comments** for easy discussion
- 🏢 **Centrally managed** by Attentive's DevOps team
- 🔐 **Secrets inherited** from organization settings

## Setup

This workflow uses Attentive's reusable workflow from `attentive-mobile/.github`, which means:

- ✅ Most configuration is handled centrally
- ✅ Secrets may already be configured at the org level
- ✅ Updates are managed by the platform team

### Check if Additional Setup is Needed

The workflow should work automatically if your repository inherits organization secrets. If reviews aren't posting, you may need to:

1. **Verify API key is available** - Check with your team if `ANTHROPIC_API_KEY` needs to be added to your repo secrets
2. **Confirm workflow permissions** - The workflow needs `id-token: write`, `contents: read`, `pull-requests: write`, and `issues: write` (already configured in the workflow file)

## How It Works

The workflow triggers on:
- **`opened`** - When a new PR is created
- **`synchronize`** - When new commits are pushed to the PR
- **`review_requested`** - When someone explicitly requests a review

The centralized workflow (maintained by Attentive's platform team) will:
1. Fetch the PR diff
2. Send it to Claude API for review
3. Post the review as a comment on the PR

## Customization

Since this uses a reusable workflow from `attentive-mobile/.github`, customization options are:

### Request Changes to the Central Workflow

If you need different behavior (model selection, prompt changes, etc.), reach out to the platform team who maintains the central workflow. This ensures all teams benefit from improvements.

### Adjust Trigger Events

You can modify when the review runs by editing the `types` in your local workflow file:

```yaml
on:
  pull_request:
    types: [review_requested, synchronize, opened]  # Customize these
```

Options:
- `opened` - New PRs
- `synchronize` - New pushes
- `reopened` - Reopened PRs
- `review_requested` - Explicit review requests
- `ready_for_review` - When draft is marked ready

## Troubleshooting

### Reviews not posting

1. **Check the Actions tab** - Look for failed workflow runs
2. **Verify secrets** - Confirm `ANTHROPIC_API_KEY` is available (may be org-level)
3. **Check permissions** - Ensure the workflow has the required permissions (already configured)
4. **Ask for help** - If issues persist, reach out to the platform team or in `#ask-devops`

### Workflow not triggering

- Make sure the workflow file is committed to your default branch
- Verify the PR events match the configured triggers
- Check repository settings allow Actions to run

### Need to disable temporarily

Comment out or delete the workflow file from your branch. You can always restore it later.

## Getting Help

- **Central workflow issues** - Contact the platform team who maintains `attentive-mobile/.github`
- **Repository-specific issues** - Check with your team or in `#ask-devops`
- **Feature requests** - Suggest improvements to the central workflow so all teams benefit

## Security Notes

- API credentials are managed at the organization level
- Reviews are posted using GitHub's provided token
- The workflow has minimal permissions: only what's needed to read code and post comments
