package frontend

import "strings"

type Command struct {
	Name string
	Args []string
}

func (c Command) String() string {
	parts := append([]string{c.Name}, c.Args...)
	return strings.Join(parts, " ")
}
