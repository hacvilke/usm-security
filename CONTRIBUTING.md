# Contributing to USM Security

Thank you for your interest in contributing to Universal Security Module (USM). This document outlines the guidelines and rules for contributing to this project.

## Important Rules

### Brand Protection

**DO NOT:**
- Copy the USM brand, name, or identity for your own projects
- Rebrand USM as your own work without proper attribution
- Remove or modify license headers
- Claim authorship of this project
- Use USM's name, logo, or branding in derivative works without permission

**DO:**
- Provide proper attribution when using USM in your projects
- Fork the repository if you want to make custom versions
- Clearly indicate if your project is based on or inspired by USM
- Respect the MIT license requirements

### Source Attribution

**DO NOT:**
- Show USM as the source of your anti-cheat if you've significantly modified it
- Imply that USM endorses your derivative work
- Use USM's reputation to promote unrelated projects

**DO:**
- Clearly state what portions are from USM and what are your own work
- Link to the original USM repository when appropriate
- Be transparent about modifications and improvements

## Pull Request Guidelines

### Before Submitting a PR

1. **Fork the Repository** - Create your own fork to work on changes
2. **Create a Branch** - Use a descriptive branch name (e.g., `fix/movement-validation` or `feature/webhook-integration`)
3. **Test Thoroughly** - Ensure your changes work correctly and don't break existing functionality
4. **Follow Code Style** - Match the existing code style and formatting
5. **Update Documentation** - Update relevant documentation if needed
6. **Add Tests** - If applicable, add tests for new functionality

### PR Requirements

- **Clear Description** - Explain what your PR does and why it's needed
- **Testing Evidence** - Describe how you tested your changes
- **No Breaking Changes** - Avoid breaking existing functionality unless absolutely necessary
- **Code Quality** - Code should be clean, well-commented, and follow Luau best practices
- **Server-Side Only** - Security scripts must remain server-side only
- **Configuration** - New features should be configurable through USM_Configuration.lua

### PR Process

1. Submit your PR with a clear title and description
2. Wait for review - maintainers will review your PR
3. Address feedback - make requested changes promptly
4. Keep PRs focused - one PR per feature/fix is preferred
5. Be patient - maintainers have other responsibilities

## Code Standards

### Lua/Luau Guidelines

- Use meaningful variable and function names
- Add comments for complex logic
- Follow the existing code structure
- Use proper error handling with pcall
- Validate server-side execution for security scripts
- Keep functions focused and modular

### Security Considerations

- **Never trust the client** - All security decisions must be server-side
- **Use suspicion scoring** - Build evidence over time instead of immediate bans
- **Handle edge cases** - Consider network latency, legitimate game mechanics
- **Test thoroughly** - Test with various network conditions and player behaviors
- **Document changes** - Explain why a security change is necessary

## Types of Contributions

### Bug Fixes

- Clearly describe the bug and how to reproduce it
- Explain your fix and why it works
- Ensure the fix doesn't introduce new issues
- Test the fix in multiple scenarios

### New Features

- Explain the feature's purpose and use case
- Ensure it's configurable through USM_Configuration.lua
- Add documentation for the new feature
- Consider performance implications
- Make it optional if it might affect existing users

### Documentation

- Keep documentation clear and concise
- Include code examples where helpful
- Update version numbers in documentation
- Ensure consistency across documentation files

### Performance Improvements

- Benchmark before and after changes
- Ensure improvements don't break functionality
- Document performance gains
- Consider edge cases

## What We're Looking For

- Server-side anti-cheat improvements
- New detection methods based on Roblox Dev Forum best practices
- Performance optimizations
- Better documentation
- Bug fixes
- Configuration improvements

## What We're NOT Looking For

- Client-side security decisions (all must be server-side)
- Aggressive detection methods that cause false positives
- Features that compromise player privacy
- Breaking changes without good reason
- Rebranding or removal of attribution

## License

By contributing to USM, you agree that your contributions will be licensed under the MIT License, the same license as the project.

## Getting Help

- Read the existing documentation first
- Check existing issues and PRs
- Ask questions in issues if something is unclear
- Be respectful and constructive in all communications

## Code of Conduct

- Be respectful to all contributors
- Provide constructive feedback
- Focus on what is best for the community
- Show empathy towards other community members

## Recognition

Contributors who make significant contributions will be recognized in the project's contributor list. However, the primary recognition comes from helping make Roblox safer for everyone.

## Contact

For questions about contributing that aren't covered here, please open an issue on GitHub.

---

Thank you for following these guidelines and for helping improve USM Security!
