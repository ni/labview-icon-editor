# Echo

The `Echo` command returns the text it receives without modification. It can be
used to verify that the CLI is wired correctly or to inspect argument passing.

## Example
### Library

```csharp
var echoed = EchoCommand.Execute("ping");
// echoed == "ping"
```

### CLI

```bash
x-cli echo hello
# stdout: hello
```
