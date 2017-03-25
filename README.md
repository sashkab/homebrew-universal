# Homebrew-universal: Universal formulae for the Homebrew package manager 🍻

Sometime in early 2017, [Homebrew core developers decided][1] that there is no longer a need to keep
universal formulae in the repository and removed them. Some of these formulae I need to maintain 
universal versions of the Python interpreter on macOS, so I decided to create a tap I can use.


## How to use?

```bash
brew install sashkab/universal/FORMULAE --universal
```


[1]: https://github.com/Homebrew/homebrew-core/pull/9641#issuecomment-280746019


## Work in progress

Currently copied formulae conflicts with one in the homebrew-core.
