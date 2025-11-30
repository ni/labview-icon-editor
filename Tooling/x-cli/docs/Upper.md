# Upper

The `Upper` command converts the supplied text to uppercase using the
invariant culture. It can help normalize input or demonstrate simple string
transformations.

## Example
### Library

```csharp
var result = UpperCommand.Execute("hello");
// result == "HELLO"
```

### CLI

```bash
x-cli upper "Hello World"
# stdout: HELLO WORLD
```
