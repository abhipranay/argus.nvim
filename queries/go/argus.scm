; argus.nvim treesitter queries for Go
; These queries capture top-level declarations for outline display

; Package clause
(package_clause
  (package_identifier) @package.name) @package

; Function declarations
(function_declaration
  name: (identifier) @function.name
  parameters: (parameter_list) @function.params) @function

; Method declarations
(method_declaration
  receiver: (parameter_list
    (parameter_declaration
      name: (identifier)? @method.receiver_name
      type: (_) @method.receiver_type))
  name: (field_identifier) @method.name
  parameters: (parameter_list) @method.params) @method

; Type declarations - struct
(type_declaration
  (type_spec
    name: (type_identifier) @struct.name
    type: (struct_type))) @struct

; Type declarations - interface
(type_declaration
  (type_spec
    name: (type_identifier) @interface.name
    type: (interface_type))) @interface

; Type declarations - alias/other
(type_declaration
  (type_spec
    name: (type_identifier) @type.name
    type: (_) @type.underlying)) @type

; Const declarations
(const_declaration
  (const_spec
    name: (identifier) @const.name)) @const

; Var declarations
(var_declaration
  (var_spec
    name: (identifier) @var.name)) @var

; Comments (for association with declarations)
(comment) @comment
