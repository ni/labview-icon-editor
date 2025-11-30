# Reverse

The `Reverse` command returns the supplied text in reverse order. This can be
useful for quick transformations or verifying string handling.

## Example
### Library

```csharp
var result = ReverseCommand.Execute("abcd");
// result == "dcba"
```

### CLI

```bash
x-cli reverse "hello world"
# stdout: dlrow olleh
```
