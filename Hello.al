codeunit 50100 "Hello World"
{
    trigger OnRun()
    begin
        Message('Hello from AL in a Codespace!');
    end;
}
