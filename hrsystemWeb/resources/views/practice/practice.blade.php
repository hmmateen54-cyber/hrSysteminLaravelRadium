<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Query Practice</title>
    @vite(['resources/css/app.css', 'resources/css/design-system.css', 'resources/js/app.js'])
</head>
<body>

    <h1>Laravel Query Practice</h1>

    <h2>Employees</h2>
    <h2>Total Employees : </h2>

    <table border="1" cellpadding="10">
        <thead>
            <tr>
                <th>Name</th>
                <th>Email ID</th>
                <th>Basic Salary</th>
                <th>Net Salary</th>
            </tr>
        </thead>

        <tbody>
            
                <tr>
                    
                    <td>{{ $employees}}</td>
                </tr>
            
        </tbody>
    </table>
</body>
</html>

