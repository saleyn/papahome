# Papa Home Visit Service

[![build](https://github.com/saleyn/papahome/actions/workflows/main.yml/badge.svg)](https://github.com/saleyn/papahome/actions/workflows/main.yml)

## Assignment

Create a "Home Visit Service" application with the following functionality:

- Users must be able to create an account. They can perform either or both of
two roles: a member (who requests visits) and a pal (who fulfills visits).
- As a member, a user can request visits.
- When a user fulfills a visit, the minutes of visit's duration are debited from
the visit requester's account and credited to the pal's account, minus a 15%
overhead fee.
- If a member's account has a balance of 0 minutes, they cannot request any more
visits until they fulfill visits themselves.

This application may be command-line or API-only. It does not require a
graphical UI or web interface.

## Assumptions

- We assume that a member upon creation gets a signup bonus of the number of
minutes. When such a credit is issued, a transaction record is created with the
details of the credit for auditing purposes.

- Though my preferred choice for this implementation would be to create a
Phoenix/LiveView interface, the requirements state to create a command-line or
API-only application.  While creating a RESTful API would be a reasonable choice
if this system were to be used by other clients, such as by the UI, for the
purpose of this assignment, we want to keep the implementation simple, such that
it would not require any other dependencies or tools needed to verify its
functionality.  For this reason we are going to stick with creating a
command-line (CLI) application that has one script as its API end-point.

- The assignment lists tasks to be performed (such as companionship and
conversation) as an attribute of the `Visit` entity.  For adherence to the
assignment we will store the tasks in a single field on the `visit` record, even
though, this design violates the 1st normal form of db normalization.

- If a member is simultaneously a pal, then the pal cannot fulfill his/her own
minutes and his own visit requests are not visible to him/herself.

- We assume that dates are in UTC time zone.

## Design

The application we are going to build will store data in a database and use Ecto
library to make changes to data.

For simplicity the application will be escriptized to present itself as a single
embedded executable.

The naming convention selected implies the use of [singular entity
names](https://bookshelf.erwin.com/bookshelf/public_html/2021R1/Content/References/Data%20Modeling%20Overview/Entity%20and%20Attribute%20Names.html).

Description of entities used in this project:

- `User` - a main actor in the service that can be either a member or a pal or
both.
- `Visit` - a visit detail that is requested by a member.
- `Transaction` - a transaction reflects a visit fulfilled by a pal or a credit
issued to a member.

We are going to use a compile-time dependency `typed_ecto_schema`, which is a
project that compiles a `typed_schema` into a schema with a typespec,
reducing the amount of code necessary to define a schema and its associated type
at least two fold.  This, along with another project called `typed_struct` are
very worthy compile-time additions to any Elixir project.

The CLI script provided with this project implements a set of basic commands for
creating users, visits and fulfilling visits.

The fee percentage (defaults to 15%) is made configurable, and can be customized
using the `config :papahome, :fee_overhead` option.

The main actions which create a visit request and fulfill visits require updates
to multiple tables.  As such these updates are implemented using `Ecto.Multi` to
ensure atomic updates in the context of a single transaction.

## Security

Given the time limits for this assignment, there's no explicit authentication
implemented in the CLI aside from the database access control by environment
variables `DB_USER`, `DB_PASS`, and `DB_NAME`.

## Source Tree
```
.
├── config                        - compile and runtime configuration options
├── lib
│   └── papahome
│       ├── application.ex        - application startup file
│       ├── cli.ex                - command-line interface
│       ├── repo.ex               - project's DB repository
│       └── schema                - database schema implementation
│           ├── transaction.ex    - transaction schema
│           ├── user.ex           - user schema
│           └── visit.ex          - visit schema
├── papahome                      - binary CLI escript
├── priv
│   └── repo
│       └── migrations            - database migration scripts
├── README.md
├── mix.exs                       - main Elixir mix project file
└── test                          - unit tests
```

## Installation

The project can be downloaded from Github:

```bash
$ git clone https://github.com/saleyn/papahome
```

To build the project, execute:

```bash
$ make
$ make test
$ make bootstrap
```

The first command builds the project and creates a CLI escript called `papahome`.
The last command bootstraps the database by creating the schema and performing
necessary migrations.

Run the CLI script for printing help options:

```
$ ./papahome -h
./papahome Options

This script is the CLI for the Papa Home Visit system.

To customize the database login, export the following environment variables:

  "DB_NAME" - database name
  "DB_USER" - database user
  "DB_PASS" - user's password
  "DB_HOST" - database host

Below is the list of supported commands:

Options:
========

help | -h | --help
  - Print this help screen

create [member|pal|pal-member|member-pal] Email --first-name=First --last-name=Last [--balance=NNN]
  - Create a member, a pal or both

    Example: "create member some@email.com --first-name=Alex --last-name=Brown"

create visit MemberEmail --minutes=Minutes [--date=VisitDate] [--task=Tasks]
  - Create a visit request by a member identified by MemberEmail. Minutes
    can be an integer or "max" for all available minutes.  If date is not
    specified, it defaults to tomorrow.  Tasks can be a comma-delimited list
    of tasks.

    Example: "create visit some@email.com --minutes=100 --date='2023-06-08 19:00:00'"

fulfill visit PalEmail [--date=AsOfDate]
  - Try to fulfill a visit by a pal. Optionally provide a date filter to only
    consider visits on or after AsOfDate.

    Example: "fulfill visit pal@email.com"

user Email
  - Get user's information and balance

list users
  - List registered users

list visits
  - List requested visits

list [member|pal] transactions Email
  - List transactions for a given member/pal email

add minutes MemberEmail Minutes
  - Add minutes to a member

    Example: "add minutes some@email.com 100"
```

## Example

Below we illustrate the CLI in action by a walk-trough of basic functionality
to create a member, a pal, request visit minutes, and fulfil a visit request.

```
$ ./papahome create member benny@gmail.com --first-name=Ben --last-name=Worth
Created member ID=1

$ ./papahome create pal alex@gmail.com --first-name=Alex --last-name=Moore
Created pal ID=2

$ ./papahome create pal-member alice@gmail.com --first-name=Alice --last-name=Gore
Created pal-member ID=3

$ ./papahome list users
ID        | Email                | FirstName            | LastName             | Mem | Pal | Balance
----------+----------------------+----------------------+----------------------+-----+-----+--------
1         | benny@gmail.com      | Ben                  | Worth                |  x  |     | 100
2         | alex@gmail.com       | Alex                 | Moore                |     |  x  | 0
3         | alice@gmail.com      | Alice                | Gore                 |  x  |  x  | 100

$ ./papahome user benny@gmail.com
User:     Ben Worth <benny@gmail.com>
UserID:   1
IsMember: true
IsPal:    false
Balance:  100

$ ./papahome create visit benny@gmail.com --minutes=60 --task=companionship
Created visit for member benny@gmail.com: ID=1

$ ./papahome create visit benny@gmail.com --minutes=max --task=conversation
Created visit for member benny@gmail.com: ID=2

# Check that a member cannot create visits if there's not enough minutes in the balance
$ ./papahome create visit benny@gmail.com --minutes=10 --task=conversation
ERROR: member doesn't have enough minutes in the balance

$ ./papahome create visit alice@gmail.com --minutes=50 --task=walking
Created visit for member alice@gmail.com: ID=3

$ ./papahome list visits
ID        | Date                 | Minutes              | Member                         | Tasks
----------+----------------------+----------------------+--------------------------------+-------------
1         | 2023-02-15 15:44:35Z | 60                   | benny@gmail.com                | companionship
2         | 2023-02-15 15:44:43Z | 40                   | benny@gmail.com                | conversation
3         | 2023-02-15 15:44:58Z | 50                   | alice@gmail.com                | walking

$ ./papahome fulfill visit alex@gmail.com
Visit fulfilled by pal alex@gmail.com: TxnID=2 Minutes=51 Fee=9

$ ./papahome fulfill visit alex@gmail.com
Visit fulfilled by pal alex@gmail.com: TxnID=3 Minutes=34 Fee=6

$ ./papahome fulfill visit alice@gmail.com            # NOTE: Alice cannot fulfill her own visit requests!
ERROR: no visits available at this time

$ ./papahome fulfill visit alex@gmail.com             # NOTE: pal Alex can fulfill Alice's visit request
Visit fulfilled by pal alex@gmail.com: TxnID=5 Minutes=43 Fee=7

$ ./papahome fulfill visit alex@gmail.com
ERROR: no visits available at this time

$ ./papahome list pal transactions alex@gmail.com
ID        | VisitDate            | Member               | Pal                  | Minutes | Fee   | Description
----------+----------------------+----------------------+----------------------+---------+-------+------------
5         | 2023-02-15 15:44:58Z | alice@gmail.com      | alex@gmail.com       | 43      | 7     | fulfillment
4         | 2023-02-15 15:44:43Z | benny@gmail.com      | alex@gmail.com       | 34      | 6     | fulfillment
3         | 2023-02-15 15:44:35Z | benny@gmail.com      | alex@gmail.com       | 51      | 9     | fulfillment

$ ./papahome list member transactions benny@gmail.com
ID        | VisitDate            | Member               | Pal                  | Minutes | Fee   | Description
----------+----------------------+----------------------+----------------------+---------+-------+------------
4         | 2023-02-15 15:44:43Z | benny@gmail.com      | alex@gmail.com       | 34      | 6     | fulfillment
3         | 2023-02-15 15:44:35Z | benny@gmail.com      | alex@gmail.com       | 51      | 9     | fulfillment
1         |                      | benny@gmail.com      |                      | 100     | 0     | signup credit

$ ./papahome add minutes benny@gmail.com 100
added 100 to member: balance=100

$ ./papahome list member transactions benny@gmail.com
ID        | VisitDate            | Member               | Pal                  | Minutes | Fee   | Description
----------+----------------------+----------------------+----------------------+---------+-------+------------
6         |                      | benny@gmail.com      |                      | 100     | 0     | added minutes
4         | 2023-02-15 15:44:43Z | benny@gmail.com      | alex@gmail.com       | 34      | 6     | fulfillment
3         | 2023-02-15 15:44:35Z | benny@gmail.com      | alex@gmail.com       | 51      | 9     | fulfillment
1         |                      | benny@gmail.com      |                      | 100     | 0     | signup credit
```
