<!DOCTYPE html>
<html>
<head>
    <title>Query Practice</title>
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

