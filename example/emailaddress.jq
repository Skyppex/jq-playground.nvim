# JQ filter example.

[
  .employees[]
  | (.firstName[0:1] + "." + .lastName) as $name
  | ($name + "@company.com") as $email
  | . += {"emailAddress": ($email | ascii_downcase)}
]
