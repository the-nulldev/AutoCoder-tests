def greet_user(user_name, user_age):
    print(f'Hello, {user_name}! You are {user_age} years old.')

def main():
    name = input('Please enter your name: ')
    age = input('Please enter your age: ')
    greet_user(name, age)
    print('Goodbye!')

if __name__ == '__main__':
    main()
